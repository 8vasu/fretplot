--- fretplot.lua
--- Copyright 2025-- Soumendra Ganguly
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   https://www.latex-project.org/lppl.txt
-- and version 1.3c or later is part of all distributions of LaTeX
-- version 2008 or later.
--
-- This work has the LPPL maintenance status `author-maintained'.
-- 
-- The Current Maintainer of this work is Soumendra Ganguly.
--
-- This work consists of the files fretplot.sty, fretplot.lua,
-- doc_fretplot.tex, doc_fretplot.pdf, README.md, and LICENSE.

-----------------------------------------------------------------------------
-- Batch generation of scale and chord diagrams for guitar-like instruments.|
-----------------------------------------------------------------------------

------ The following section defines some convenience functions.

-- return array obtained by splitting string "str" based on delimiter "sep"
local function split(str, sep)
   local a = {}

   sep = sep or "%s"
   for s in string.gmatch(str, "([^"..sep.."]+)") do
      a[#a + 1] = s
   end

   return a
end

-- "func" is a function
-- if "tbl" is the table {k1=v1, ..., kn=vn}, then return the table {k1=func(v1), ..., kn=func(vn)}
local function map(func, tbl)
   local t = {}

   for k, v in pairs(tbl) do
      t[k] = func(v)
   end

   return t
end

-- return the sum of the members of an array "arr" of numbers
local function sum(arr)
   local x = 0

   for _, y in pairs(arr) do
      x = x + y
   end

   return x
end

-- check if the table "tbl" contains the value "val" (under any key)
local function tblcontains(tbl, val)
   for _, v in pairs(tbl) do
      if v == val then
	 return true
      end
   end

   return false
end

-- extend the array "arr1" by the value of the array "arr2" in-place; maintain order of elements; return "arr1"
local function arrextend(arr1, arr2)
   for _, v in ipairs(arr2) do
      arr1[#arr1 + 1] = v
   end

   return arr1
end

-- rotate array
local function rotarr(arr, index)
   local ret = {}

   index = index % #arr

   for i = index, #arr do
      ret[#ret + 1] = arr[i]
   end

   for i = 1, (index-1) do
      ret[#ret + 1] = arr[i]
   end

   return ret
end

-- write string to file at given path
local function strtopath(out_path, out_content)
   local out_handle = nil
   local orig_stdout = nil

   out_handle = io.open(out_path, "w")
   orig_stdout = io.output()
   io.output(out_handle)
   io.write(out_content)
   io.close(out_handle)
   io.output(orig_stdout)
end

------ The following section defines the fretplot file format.
------ The freplot file format describes the fretboard of a
------ musical instrument like the guitar.

local FP_COMMENT = "#"
local FP_INCLUDE_DIRECTIVE = "include"

-- note notation: <string_index,fret_index>
local FP_NOTE_START = "<" -- must be a single character
local FP_NOTE_END = ">" -- must be a single character
local FP_NOTE_SEP = "," -- must be a single character
local FP_DEFAULT_NOTE_LABEL = ""

-- barre notation: <start_string_index-end_string_index,fret_index>
local FP_BARRE_START = "<" -- must be a single character
local FP_BARRE_END = ">" -- must be a single character
local FP_BARRE_SEP = "," -- must be a single character
local FP_BARRE_RANGE = "-" -- must be a single character

---------------------------
-- Boolean parameters start
---------------------------
local FP_BOOL_TRUE = "True"
local FP_BOOL_FALSE = "False"

-- list ALL boolean parameters and their default values here
local FP_BOOLEAN_DEFAULTS = {
   ["onf0"] = false,
   ["sovf"] = true
}

local FP_BOOLEAN_NEGATE_COMMAND = "flip"
-------------------------
-- Boolean parameters end
-------------------------

-----------------------------
-- Numerical parameters start
-----------------------------
-- list ALL numerical parameters and their default values here
local FP_NUMERICAL_DEFAULTS = {
   ["zoom"] = 1.0,
   ["rotn"] = 0,
   ["numfrt"] = 12,
   ["numstr"] = 6
}

-- addition
local function fp_operator_add(bd, k, v)
   bd[k] = bd[k] + v
end

-- subtraction
local function fp_operator_sub(bd, k, v)
   bd[k] = bd[k] - v
end

-- multiplication
local function fp_operator_mul(bd, k, v)
   bd[k] = bd[k] * v
end

-- division
local function fp_operator_div(bd, k, v)
   if v == 0 then
      error("attempted to divide '"..k.."' by 0")
   end

   bd[k] = bd[k] / v
end

-- remainder
local function fp_operator_mod(bd, k, v)
   if v == 0 then
      error("attempted to divide '"..k.."' by 0 (cannot find remainder modulo 0)")
   end

   bd[k] = bd[k] % v
end

-- exponentiation
local function fp_operator_exp(bd, k, v)
   bd[k] = bd[k] ^ v
end

local FP_NUMERICAL_OPERATORS = {
   ["+"] = fp_operator_add,
   ["-"] = fp_operator_sub,
   ["*"] = fp_operator_mul,
   ["/"] = fp_operator_div,
   ["%"] = fp_operator_mod,
   ["^"] = fp_operator_exp
}
---------------------------
-- Numerical parameters end
---------------------------

local function fp_operator_delimiter_extend(bd, k, v, delim)
   if not bd[k] then
      bd[k] = v
   else
      bd[k] = bd[k]..delim..v
   end
end

------------------------
-- List parameters start
------------------------
local FP_EMPTY_LIST = ""
local FP_LIST_DELIMITER = " "

-- list ALL list parameters and their default values here
local FP_LIST_DEFAULTS = {
   ["frets"] = "0 1 2 3 4 5 6 7 8 9 10 11 12",
   ["strings"] = "1 2 3 4 5 6",
   ["notes"] = FP_EMPTY_LIST,
   ["barres"] = FP_EMPTY_LIST
}

-- sets list to empty
local FP_LIST_CLEAR_COMMAND = "void"

-- extend list
local function fp_operator_ext(bd, k, v)
   return fp_operator_delimiter_extend(bd, k, v, FP_LIST_DELIMITER)
end

-- remove from list
local function fp_operator_rem(bd, k, v)
   local final = nil
   local to_remove = nil

   if bd[k] then
      final = FP_EMPTY_LIST
      to_remove = split(v, FP_LIST_DELIMITER)

      for _, x in pairs(split(bd[k], FP_LIST_DELIMITER)) do
	 if not tblcontains(to_remove, x) then
	    final = final..FP_LIST_DELIMITER..x
	 end
      end

      bd[k] = final
   end
end

local FP_LIST_OPERATORS = {
   [">"] = fp_operator_ext,
   ["<"] = fp_operator_rem
}
----------------------
-- List parameters end
----------------------

-------------------------
-- Style parameters start
-------------------------
local FP_STYLE_DELIMITER = ","

-- list ALL TYPES of style parameters (for fretplot files; not
-- fretplot scale style files) and their default values here
local FP_STYLE_DEFAULTS = {
   ["fx"] = "solid,line width=0.6,color=black",
   ["sx"] = "solid,line width=0.6,color=black",
   ["bx"] = "fill=black,draw=black",
   ["nx"] = "shape=rectangle,draw=black,text=white,fill=black"
}

-- extend style
local function fp_operator_cat(bd, k, v)
   return fp_operator_delimiter_extend(bd, k, v, FP_STYLE_DELIMITER)
end

local FP_STYLE_CONCAT = "&"
-----------------------
-- Style parameters end
-----------------------

-- generic data type check function
local function check_data_type(param, param_tbl)
   for k, _ in pairs(param_tbl) do
      if param == k then
	 return true
      end
   end

   return false
end

local function is_boolean(param)
   return check_data_type(param, FP_BOOLEAN_DEFAULTS)
end

local function is_numerical(param)
   return check_data_type(param, FP_NUMERICAL_DEFAULTS)
end

local function is_list(param)
   return check_data_type(param, FP_LIST_DEFAULTS)
end

local function is_style(param)
   for k, _ in pairs(FP_STYLE_DEFAULTS) do
      if string.sub(param, 1, 2) == k then
	 return true
      end
   end

   return false
end

------ The following section implements a fretplot file
------ interpreter that can convert to tikz.

local function frets_to_tikz(board_data, scl, scldv2, nstr, fpwrite)
   local style = nil
   local label = nil
   local nstrscl = nstr * scldv2
   local nstrp1scl = nstrscl + scldv2
   local fcoord = nil

   -- i = fret index
   for _, i in pairs(split(board_data["frets"], FP_LIST_DELIMITER)) do
      style = board_data["fx"..i] or FP_STYLE_DEFAULTS["fx"] -- fret style
      label = board_data["fl"..i] -- fret label

      fcoord = tonumber(i) * scl
      fpwrite("\\draw["..style.."] ("..tostring(fcoord)..","..tostring(scldv2)..") -- ("..tostring(fcoord)..","..tostring(nstrscl)..");\n")
      if label then
	 fpwrite("\\node at ("..tostring(fcoord + scldv2)..","..tostring(nstrp1scl)..") {"..label.."};\n")
      end
   end
end

local function strings_to_tikz(board_data, scl, scldv2, nfrt, fpwrite)
   local style = nil
   local label = nil
   local nfrtscl = nfrt * scl
   local scoord = nil

   -- i = string index
   for _, i in pairs(split(board_data["strings"], FP_LIST_DELIMITER)) do
      style = board_data["sx"..i] or FP_STYLE_DEFAULTS["sx"] -- string style
      label = board_data["sl"..i] -- string label

      scoord = tonumber(i) * scldv2
      fpwrite("\\draw["..style.."] (0,"..tostring(scoord)..") -- ("..tostring(nfrtscl)..","..tostring(scoord)..");\n")
      if label then
	 if board_data["onf0"] then
	    fpwrite("\\node at ("..tostring(scldv2)..","..tostring(scoord)..") {"..label.."};\n")
	 else
	    fpwrite("\\node at ("..tostring(-scl)..","..tostring(scoord)..") {"..label.."};\n")
	 end
      end
   end
end

local function barres_to_tikz(board_data, scl, scldv2, fpwrite)
   local i = nil
   local fi = nil
   local si_start = nil
   local si_end = nil
   local style = nil
   local fcoord = nil

   -- p = barre coordinates <string1-string2,fret>
   for _, p in pairs(split(board_data["barres"], FP_LIST_DELIMITER)) do
      i = string.find(p, FP_BARRE_SEP)
      fi = tonumber(string.sub(p, i+1, -2)) -- fret index
      srange = string.sub(p, 2, i-1) --string1-string2

      i = string.find(srange, FP_BARRE_RANGE)
      si_start = tonumber(string.sub(srange, 1, i-1)) -- start string index
      si_end = tonumber(string.sub(srange, i+1)) -- end string index

      style = board_data["bx"..p] or FP_STYLE_DEFAULTS["bx"] -- barre style

      if fi == 0 and board_data["onf0"] then
	 fpwrite("\\draw["..style.."] (0,"..tostring(si_start * scldv2)..") to [out=255,in=105] (0,"..tostring(si_end * scldv2)..") to [out=100,in=260] cycle;\n")
      else
	 fcoord = (fi - 0.5) * scl
	 fpwrite("\\draw["..style.."] ("..tostring(fcoord)..","..tostring(si_start * scldv2)..") to [out=255,in=105] ("..tostring(fcoord)..","..tostring(si_end * scldv2)..") to [out=100,in=260] cycle;\n")
      end
   end
end

local function notes_to_tikz(board_data, scl, scldv2, fpwrite)
   local i = nil
   local fi = nil
   local si = nil
   local style = nil
   local label = nil

   -- p = note coordinates <string,fret>
   for _, p in pairs(split(board_data["notes"], FP_LIST_DELIMITER)) do
      i = string.find(p, FP_NOTE_SEP)
      fi = tonumber(string.sub(p, i+1, -2)) -- fret index
      si = tonumber(string.sub(p, 2, i-1)) --string index

      style = board_data["nx"..p] or FP_STYLE_DEFAULTS["nx"] -- note style
      label = board_data["nl"..p] or FP_DEFAULT_NOTE_LABEL -- note label

      if fi == 0 and board_data["onf0"] then
	 fpwrite("\\node["..style.."] at (0,"..tostring(si * scldv2)..") {"..label.."};\n")
      else
	 fpwrite("\\node["..style.."] at ("..tostring((fi - 0.5) * scl)..","..tostring(si * scldv2)..") {"..label.."};\n")
      end
   end
end

local function compile_to_tikz(board_data, fpwrite)
   local scl = board_data["zoom"]
   local nfrt = board_data["numfrt"]
   local nstr = board_data["numstr"]
   local scldv2 = -(scl/2)

   -- render fretboard
   fpwrite("\\begin{tikzpicture}[rotate="..tostring(board_data["rotn"]).."]\n")

   -- draw frets and strings
   if board_data["sovf"] then
      frets_to_tikz(board_data, scl, scldv2, nstr, fpwrite)
      strings_to_tikz(board_data, scl, scldv2, nfrt, fpwrite)
   else
      strings_to_tikz(board_data, scl, scldv2, nfrt, fpwrite)
      frets_to_tikz(board_data, scl, scldv2, nstr, fpwrite)
   end

   -- draw barres and notes
   barres_to_tikz(board_data, scl, scldv2, fpwrite)
   notes_to_tikz(board_data, scl, scldv2, fpwrite)

   fpwrite("\\end{tikzpicture}\n")
end

local FP_LINE_SYNTAX_ERROR = [[
fretplot file formatting error: lines should look
like "firstword lots of data" with a single space
separating "firstword" and "lots of data";
"lots of data" cannot be empty and cannot start
with a space character
]]

-- Check syntax of line of an fp file (fretplot file) and parse it.
-- An fp file will have lines of form "firstword lots of data", where
-- "firstword" and "lots of data" must be separated by a single " " (space),
-- "lots of data" cannot be empty, and the first character of
-- "lots of data" cannot be a space character ("%s"). We will
-- store "firstword" as key and "lots of data" as value in some
-- lua table in functions such as "load_board_data" and "load_scale_style".
local function fp_parse_line(line)
   local first_char = string.sub(line, 1, 1)
   local i = nil
   local key = nil
   local val = nil

   -- ignore empty lines and comments
   if first_char == "" or first_char == FP_COMMENT then
      return nil
   end

   -- find index of first " " (space)
   i,_ = string.find(line, " ")

   -- line has no spaces
   if not i then
      error(FP_LINE_SYNTAX_ERROR)
   end

   val_fc = string.sub(line, i+1, i+1)
   -- first char of "lots of data" is "" or matches "%s"
   if val_fc == "" or string.find(val_fc, "%s") then
      error(FP_LINE_SYNTAX_ERROR)
   end

   key = string.sub(line, 1, i-1) -- "firstword"
   val = string.sub(line, i+1) -- "lots of data"

   return key, val, first_char
end

-- parse the fretplot file to load fretboard data;
-- data will be stored in the lua table named board_data
local function load_board_data(fretplot_file_path, board_data, load_defaults)
   local first_char = nil
   local i = nil
   local key = nil
   local val = nil
   local bk_val = nil

   if load_defaults then
      for k, v in pairs(FP_NUMERICAL_DEFAULTS) do
	 board_data[k] = v
      end

      for k, v in pairs(FP_LIST_DEFAULTS) do
	 board_data[k] = v
      end

      for k, v in pairs(FP_BOOLEAN_DEFAULTS) do
	 board_data[k] = v
      end
   end

   if not fretplot_file_path or fretplot_file_path == "" then
      return
   end

   for line in io.lines(fretplot_file_path) do
      key, val, first_char = fp_parse_line(line)

      if not first_char then -- empty and comment lines
	 -- do nothing
      elseif key == FP_INCLUDE_DIRECTIVE then -- "val" is path to file to include
	 -- do not load default values again (let load_defaults be false)
	 load_board_data(val, board_data, false)
      elseif key == FP_LIST_CLEAR_COMMAND then -- clear (set to empty) list; name of the list is stored in "val"
	 if not is_list(val) then
	    error("attempted to clear '"..val.."', which is not a list")
	 end

	 board_data[val] = FP_EMPTY_LIST
      elseif key == FP_BOOLEAN_NEGATE_COMMAND then -- negate Boolean parameter with name stored in "val"
	 if not is_boolean(val) then
	    error("attempted to negate '"..val.."', which is not a Boolean parameter")
	 end

	 board_data[val] = not board_data[val]
      elseif is_boolean(key) then -- assign Boolean parameters
	 if val == FP_BOOL_TRUE then
	    board_data[key] = true
	 elseif val == FP_BOOL_FALSE then
	    board_data[key] = false
	 else
	    error("'"..key.."' must be "..FP_BOOL_TRUE.." or "..FP_BOOL_FALSE.." (with no surrounding spaces)")
	 end
      elseif is_numerical(key) then -- assign numerical parameters
	 board_data[key] = tonumber(val)
	 if not board_data[key] then
	    error("attempted to assign non-numerical value '"..val.."' to numerical parameter '"..key.."'")
	 end
      elseif FP_NUMERICAL_OPERATORS[first_char] then -- handle numerical operations
	 key = string.sub(key, 2)
	 if not is_numerical(key) then
	    error("attempted to perform numerical operation '"..first_char.."' on '"..key.."' which is not a numerical parameter")
	 end

	 bk_val = val
	 val = tonumber(val)
	 if not val then
	    error("attempted to perform numerical operation '"..first_char.."' on '"..key.."' with non-numerical operand '"..bk_val.."'")
	 end

	 FP_NUMERICAL_OPERATORS[first_char](board_data, key, val)
      elseif FP_LIST_OPERATORS[first_char] then -- handle list operations
	 key = string.sub(key, 2)
	 if not is_list(key) then
	    error("attempted to perform list operation '"..first_char.."' on '"..key.."' which is not a list parameter")
	 end

	 FP_LIST_OPERATORS[first_char](board_data, key, val)
      elseif first_char == FP_STYLE_CONCAT then -- handle style concatenation
	 key = string.sub(key, 2)
	 if not is_style(key) then
	    error("attempted to perform style concatenation operation '"..FP_STYLE_CONCAT.."' on '"..key.."' which is not a style parameter")
	 end

	 fp_operator_cat(board_data, key, val)
      else -- assign lists, styles, and labels
	 board_data[key] = val
      end
   end
end

-- compile a fretplot file to tikz
local function fretplot_to_tikz(fretplot_file_path, tikz_file_path)
   local tikz_file_handle = nil
   local board_data = {}
   local orig_stdout = nil

   -- load fretboard data; make sure to load default
   -- values for keys (let load_defaults be true)
   load_board_data(fretplot_file_path, board_data, true)

   -- compile to tikz
   if not tikz_file_path or tikz_file_path == "" then
      compile_to_tikz(board_data, tex.sprint)
   else
      tikz_file_handle = io.open(tikz_file_path, "w")
      orig_stdout = io.output()
      io.output(tikz_file_handle)
      compile_to_tikz(board_data, io.write)
      io.close(tikz_file_handle)
      io.output(orig_stdout)
   end
end

------ The following section implements functions that can write
------ fretplot files describing musical scales. It also defines
------ the fretplot scale style file format that describes the
------ tikz styles and labels for the notes of a musical scale
------ based on their pitch classes and/or degrees.

local FP_PITCH_CLASSES = {"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}
local FP_PITCH_CLASS_INDICES = {
   ["C"] = 0,
   ["C#"] = 1,
   ["D"] = 2,
   ["Eb"] = 3,
   ["E"] = 4,
   ["F"] = 5,
   ["F#"] = 6,
   ["G"] = 7,
   ["Ab"] = 8,
   ["A"] = 9,
   ["Bb"] = 10,
   ["B"] = 11
}

local FP_DEGREES = {"1", "b2", "2", "b3", "3", "4", "b5", "5", "b6", "6", "b7", "7"}
local FP_DEGREE_INDICES = {
   ["1"] = 0,
   ["b2"] = 1,
   ["2"] = 2,
   ["b3"] = 3,
   ["3"] = 4,
   ["4"] = 5,
   ["b5"] = 6,
   ["5"] = 7,
   ["b6"] = 8,
   ["6"] = 9,
   ["b7"] = 10,
   ["7"] = 11
}

-- ri = chromatic index of some pitch class, say "r"
-- i = an interval
--
-- returns pitch class that is at interval "i" from "r"
local function ri_i2pc(ri, i)
   return FP_PITCH_CLASSES[1 + (ri + i)%12]
end

-- r = root pitch class
-- i = an interval
--
-- returns pitch class that is at interval "i" from "r"
local function int2pc(r, i)
   return ri_i2pc(FP_PITCH_CLASS_INDICES[r], i)
end

-- sanity check for interval formula
local function intok(I)
     if sum(I) ~= 12 then
        error("sum of intervals in an interval formula must be 12")
     end
end

-- r = root pitch class of scale
-- I = interval formula of scale in terms of semitones (array)
--
-- returns an array containing the pitch classes of the scale
local function int2pc_scale(r, I)
     local ri = FP_PITCH_CLASS_INDICES[r]
     local ret = {r} -- first pitch class is "r"
     local cumuli = 0

     intok(I)

     -- find cumulative intervals and use
     -- them to find the pitch classes
     for i = 1, (#I - 1) do
	cumuli = cumuli + I[i]
	-- RHS is pitch class that is
	-- at interval "cumuli" from "r"
	ret[i+1] = ri_i2pc(ri, cumuli)
     end

     return ret
end

-- I = interval formula of scale in terms of semitones (array)
--
-- returns the degree formula of the scale (array)
local function int2deg_scale(I)
     local ret = {"1"} -- first degree is "1"
     local cumuli = 0

     intok(I)

     -- find cumulative intervals and use
     -- them to find the degrees
     for i = 1, (#I - 1) do
	cumuli = cumuli + I[i]
	-- RHS is degree that is at interval
	-- "cumuli" from root (degree "1")
	ret[i+1] = FP_DEGREES[1 + cumuli]
     end

     return ret
end

-- D = degree formula of scale without octave (array);
-- for example {"1", "b2", "b7", "7"}
--
-- returns the interval formula of the scale (array)
local function deg2int_scale(D)
     local ret = {}

     for i = 1, (#D - 1) do
	ret[i] = FP_DEGREE_INDICES[D[i+1]] - FP_DEGREE_INDICES[D[i]]
     end

     ret[#D] = 12 - sum(ret)

     return ret
end

-- PC = pitch classes of scale in ascending order (array)
--
-- returns the interval formula of the scale (array)
local function pc2int_scale(PC)
   local ret = {}

   for i = 1, (#PC - 1) do
      ret[i] = (FP_PITCH_CLASS_INDICES[PC[i+1]] - FP_PITCH_CLASS_INDICES[PC[i]])%12
   end

   ret[#PC] = 12 - sum(ret)

   return ret
end

-- r = root pitch class
-- deg = degree wrt "r" of pitch class to find
--
-- returns pitch class that has degree "deg" relative to "r"
local function deg2pc(r, deg)
   return ri_i2pc(FP_PITCH_CLASS_INDICES[r], FP_DEGREE_INDICES[deg])
end

-- r = root pitch class of scale
-- D = degree formula of scale without octave (array);
-- for example {"1", "b2", "b7", "7"}
--
-- returns pitch classes of the
-- scale in ascending order (array)
local function deg2pc_scale(r, D)
   local ri = FP_PITCH_CLASS_INDICES[r]
   local ret = {r} -- first pitch class is "r"

   for i = 2, #D do
      ret[i] = ri_i2pc(ri, FP_DEGREE_INDICES[D[i]])
   end

   return ret
end

-- r = root pitch class
-- pc = pitch class
--
-- returns degree of "pc" relative to "r"
local function pc2deg(r, pc)
   return FP_DEGREES[1 + (FP_PITCH_CLASS_INDICES[pc] - FP_PITCH_CLASS_INDICES[r])%12]
end

-- PC = pitch classes of scale in ascending order (array)
--
-- returns degree formula of scale without octave (array)
local function pc2deg_scale(PC)
   local ri = FP_PITCH_CLASS_INDICES[PC[1]]
   local ret = {"1"}

   for i = 2, #PC do
      ret[i] = FP_DEGREES[1 + (FP_PITCH_CLASS_INDICES[PC[i]] - ri)%12]
   end

   return ret
end

-- fi = a fret index; 0 <= fi <= 11
-- nfrt = number of frets
--
-- returns all fret indices
-- congruent to "fi" mod 12
local function fi2allfi(fi, nfrt)
   local ret = {}

   while fi <= nfrt do
      ret[#ret + 1] = fi
      fi = fi + 12
   end

   return ret
end

-- pc = pitch class
-- t = instrument string tuning pitch class (say, "E")
-- nfrt = number of frets
--
-- returns array containing fret indices
-- of notes belonging to pitch class "pc"
local function pc2fi(pc, t, nfrt)
   local fi = (FP_PITCH_CLASS_INDICES[pc] - FP_PITCH_CLASS_INDICES[t])%12

   return fi2allfi(fi, nfrt)
end

-- r = root pitch class, i.e. degree == "1"
-- deg = some degree (such as "1", "b3", etc)
-- t = instrument string tuning pitch class (say, "E")
-- nfrt = number of frets
--
-- returns array containing fret indices of
-- notes having degree "deg" relative to root "r"
local function deg2fi(deg, r, t, nfrt)
   local fi = (FP_PITCH_CLASS_INDICES[r] - FP_PITCH_CLASS_INDICES[t] + FP_DEGREE_INDICES[deg])%12

   return fi2allfi(fi, nfrt)
end

-- parse the fretplot scale style file to load scale style data;
-- data will be stored in the lua table named style_data
local function load_scale_style(fretplot_style_path, style_data)
   local first_char = nil
   local i = nil
   local key = nil
   local val = nil

   -- set default degree-based styles, labels for notes
   for _, v in pairs(FP_DEGREES) do
      style_data["l"..v] = v
      style_data["x"..v] = FP_STYLE_DEFAULTS["nx"]
   end

   -- set default pitch class-based styles, labels for notes
   for _, v in pairs(FP_PITCH_CLASSES) do
      style_data["l"..v] = v
      style_data["x"..v] = FP_STYLE_DEFAULTS["nx"]
   end
   style_data["lC#"] = "C\\#"
   style_data["lF#"] = "F\\#"

   if not fretplot_style_path or fretplot_style_path == "" then
      return
   end

   for line in io.lines(fretplot_style_path) do
      key, val, first_char = fp_parse_line(line)

      if first_char then
	 style_data[key] = val
      end
   end
end

-- tuning delimiter
local FP_TUNING_DELIMITER = " "
-- scale pitch class formula delimiter
local FP_PITCH_CLASS_DELIMITER = " "
-- scale degree formula delimiter
local FP_DEGREE_DELIMITER = " "
-- scale interval formula delimiter
local FP_INTERVAL_DELIMITER = " "

-- dF = scale degree formula (array)
-- pF = scale pitch classes in ascending order (array)
-- iF = scale interval formula (array)
-- dF, pF, and iF (all arrays) will be in 1-1 correspondence
-- tunstr = instrument tuning (lua string); for example "E B G D A E" (standard guitar tuning)
-- nfrt = number of frets
-- style_type = style type (possible values: "d" (degrees), "p" (pitch classes))
-- label_type = label type (possible values: "d" (degrees), "p" (pitch classes))
-- output_fretplot_path = path to output fp file containing note data
-- fretplot_include_path = optional path to fp file to be included at the end of output fp
--        file "output_fretplot_path"; if a file does not already exist at this path, then
--        a new empty file will be created
-- fretplot_style_path = optional path to input fp scale style file containing style
--        and/or label descriptions of pitch classes and/or degrees
--
-- writes a fretplot file describing a scale based on the arguments provided
local function scale_to_fretplot(dF, pF, iF,
		     tunstr, nfrt,
		     style_type, label_type,
		     output_fretplot_path,
		     fretplot_include_path, fretplot_style_path)
   local style_data = {}
   local strfi = nil
   local strnotes = nil
   local current_label = nil
   local current_style = nil
   local xF = nil -- for styles
   local lF = nil -- for labels
   local tunarr = split(tunstr, FP_TUNING_DELIMITER)
   local nstr = #tunarr
   local include_file_handle = nil
   local out_total = nil
   local out_intro = ""
   local out_notes = {}
   local out_styles_labels = ""

   if style_type == "p" then
      xF = pF
   elseif style_type == "d" then
      xF = dF
   else
      error('style type can either be "p" (use pitch class styles) or "d" (use degree styles)')
   end

   if label_type == "p" then
      lF = pF
   elseif label_type == "d" then
      lF = dF
   else
      error('label type can either be "p" (use pitch class labels) or "d" (use degree labels)')
   end

   load_scale_style(fretplot_style_path, style_data)

   out_intro = out_intro.."numfrt "..tostring(nfrt)
   out_intro = out_intro.."\nfrets "
   for fi = 0, (nfrt - 1) do
      out_intro = out_intro..tostring(fi)..FP_LIST_DELIMITER
   end
   out_intro = out_intro..tostring(nfrt)

   out_intro = out_intro.."\n\n# instrument tuning: "..tunstr
   out_intro = out_intro.."\nnumstr "..tostring(nstr)
   out_intro = out_intro.."\nstrings "
   for si = 1, (nstr - 1) do
      out_intro = out_intro..tostring(si)..FP_LIST_DELIMITER
   end
   out_intro = out_intro..tostring(nstr)

   out_intro = out_intro.."\n\n# scale pitch classes (ascending): "..table.concat(pF, FP_PITCH_CLASS_DELIMITER)
   out_intro = out_intro.."\n# scale degree formula: "..table.concat(dF, FP_DEGREE_DELIMITER)
   out_intro = out_intro.."\n# scale interval formula: "..table.concat(iF, FP_INTERVAL_DELIMITER)

   for i = 1, #pF do
      current_style = style_data["x"..xF[i]]
      current_label = style_data["l"..lF[i]]

      out_styles_labels = out_styles_labels.."\n\n#--SECTION pitch class:"..pF[i]..", degree:"..dF[i]
      for si = 1, nstr do
	 -- the array "strfi" contains the fret
	 -- indices of all the notes belonging
	 -- to the current pitch class "pF[i]"
	 -- that lie on the current string (with
	 -- index "si")
	 strfi = pc2fi(pF[i], tunarr[si], nfrt)

	 -- "strnotes" contains all notes "<si,fi>"
	 -- for all elements "fi" of "strfi",
	 -- where "si" is the current string index
	 strnotes = map(function(fi) return FP_NOTE_START..tostring(si)..FP_NOTE_SEP..tostring(fi)..FP_NOTE_END end, strfi)

	 arrextend(out_notes, strnotes)

	 out_styles_labels = out_styles_labels.."\n\n#--Subsection str index:"..tostring(si)..", str tuning:"..tunarr[si]
	 for _, note in pairs(strnotes) do
	    out_styles_labels = out_styles_labels.."\nnx"..note.." "..current_style
	    out_styles_labels = out_styles_labels.."\nnl"..note.." "..current_label
	 end
	 out_styles_labels = out_styles_labels.."\n#--Subsection end"
      end
      out_styles_labels = out_styles_labels.."\n#--SECTION end"
   end

   out_notes = "\n\nnotes "..table.concat(out_notes, FP_LIST_DELIMITER)
   out_total = out_intro..out_notes..out_styles_labels

   if fretplot_include_path and fretplot_include_path ~= "" then
      include_file_handle = io.open(fretplot_include_path, "a")

      if not include_file_handle then
	 error("could not open or create "..fretplot_include_path.." in append mode")
      end

      io.close(include_file_handle)
      out_total = out_total.."\n\n"..FP_INCLUDE_DIRECTIVE.." "..fretplot_include_path
   end

   strtopath(output_fretplot_path, out_total)
end

local FP_SCALE_DEFAULTS = {
   ["parentroot"] = "C",
   ["formulatype"] = "d",
   ["formula"] = "1 2 3 4 5 6 7",
   ["mode"] = 1,
   ["moderoot"] = nil,
   ["tuning"] = "E B G D A E",
   ["numfrets"] = 12,
   ["styletype"] = "d",
   ["labeltype"] = "d",
   ["outfpfile"] = nil,
   ["outtikzfile"] = nil,
   ["includefpfile"] = nil,
   ["scalestylefile"] = nil
}

-- formula_type = input formula type ("d" (degree), "p" (ascending pitch class), or "i" (interval))
-- parent_root = root of parent scale (ignored if "formula_type" is "p" or if "mode_root" is not nil)
-- parent_scale_formula = input formula of parent scale having type "formula_type" (lua string)
-- mode_index = mode index (integer)
-- mode_root = root of mode ("mode_root" is ignored if "formula_type" is "p")
--
-- extract degree, pitch class, and interval formulas of (mode of) scale
local function find_scale_formulas(formula_type, parent_root, parent_scale_formula, mode_index, mode_root)
   local dF = nil
   local pF = nil
   local iF = nil

   if formula_type == "d" then -- degree formula
      dF = split(parent_scale_formula, FP_DEGREE_DELIMITER)

      if mode_root then
	 iF = rotarr(deg2int_scale(dF), mode_index)
	 dF = int2deg_scale(iF)
	 pF = int2pc_scale(mode_root, iF)
      else
	 pF = rotarr(deg2pc_scale(parent_root, dF), mode_index)
	 dF = pc2deg_scale(pF)
	 iF = deg2int_scale(dF)
      end
   elseif formula_type == "p" then -- pitch class formula
      pF = rotarr(split(parent_scale_formula, FP_PITCH_CLASS_DELIMITER), mode_index)
      dF = pc2deg_scale(pF)
      -- iF = pc2int_scale(pF) -- this requires extra %12 compared to next line
      iF = deg2int_scale(dF)
   elseif formula_type == "i" then -- interval formula
      iF = map(tonumber, split(parent_scale_formula, FP_INTERVAL_DELIMITER))

      if mode_root then
	 iF = rotarr(iF, mode_index)
	 dF = int2deg_scale(iF)
	 pF = int2pc_scale(mode_root, iF)
      else
	 pF = rotarr(int2pc_scale(parent_root, iF), mode_index)
	 dF = pc2deg_scale(pF)
	 iF = deg2int_scale(dF)
      end
   else
      error('formulatype must be "d" (degree), "p" (pitch class), or "i" (interval)')
   end

   return dF, pF, iF
end

-- tex macro argument delimiter
local FP_TEX_ARG_DELIMITER = "|"
-- tex macro argument assignment operator
local FP_TEX_ARG_ASSIGN = "="

-- mstr = single tex macro argument that represents many named arguments (lua string);
-- example: "a=1|b=2"
local function fpscale_tex_macro_functionality(mstr)
   local x = nil
   local y = nil
   local z = nil
   local margs = {}
   local dF = nil
   local pF = nil
   local iF = nil
   local case_2 = false

   -- extract specified named arguments from tex macro argument
   for _, a in pairs(split(mstr, FP_TEX_ARG_DELIMITER)) do
      z = split(a, FP_TEX_ARG_ASSIGN) -- z example: {"a", "1"} or {"b", "2"}
      x = string.gsub(z[1], "%A", "") -- only keep letters
      y = z[2]
      margs[x] = y
   end

   -- apply default values of unspecified arguments
   for a, b in pairs(FP_SCALE_DEFAULTS) do
      margs[a] = margs[a] or b
   end

   -- get formulas of (mode of) scale
   dF, pF, iF = find_scale_formulas(margs["formulatype"],
				    margs["parentroot"],
				    margs["formula"],
				    tonumber(margs["mode"]),
				    margs["moderoot"])

   -- There are 2 cases:
   --
   -- 1. If an output fp filename (outfpfile) is specified,
   -- then the function will create such a file describing
   -- the desired scale, and the function will return with
   -- no further action.
   --
   -- 2. If an output fp filename is not specified, then a temporary
   -- fp file describing the desired scale will be created; this
   -- temporary file will be deleted after the program ends.
   -- This case has 2 subcases:
   -- A. If an output tikz filename (outtikzfile) is specified,
   -- then such a tikz file describing the desired scale will be
   -- created (using the temporary fp file), and the function
   -- will return with no further action.
   -- B. If an output tikz filename is not specified, then the
   -- temporary fp file will be used to generate inline tikz
   -- in your tex file; this tikz will render as a fretboard
   -- diagram describing the desired scale.

   if not margs["outfpfile"] then
      case_2 = true
      margs["outfpfile"] = os.tmpname()
   end

   scale_to_fretplot(dF, pF, iF,
		     margs["tuning"],
		     tonumber(margs["numfrets"]),
		     margs["styletype"],
		     margs["labeltype"],
		     margs["outfpfile"],
		     margs["includefpfile"],
		     margs["scalestylefile"])

   if case_2 then
      fretplot_to_tikz(margs["outfpfile"], margs["outtikzfile"])
      os.remove(margs["outfpfile"])
   end
end

------ The following section defines functions that can write
------ fretplot file templates and fretplot scale style file
------ templates.

local FP_TEMPLATE = [[zoom 1.0
rotn 0

# draw notes directly on top of fret 0
# (nut of guitar) if True and not if False
onf0 False

# draw strings over frets if True
# and frets over strings if False
sovf True

numfrt 12
frets 0 1 2 3 4 5 6 7 8 9 10 11 12

numstr 6
strings 1 2 3 4 5 6

# fret styles
fx0 solid,line width=1.2,color=black
fx1 solid,line width=0.6,color=brown
fx2 solid,line width=0.6,color=brown
fx3 solid,line width=0.6,color=brown
fx4 solid,line width=0.6,color=brown
fx5 solid,line width=0.6,color=brown
fx6 solid,line width=0.6,color=brown
fx7 solid,line width=0.6,color=brown
fx8 solid,line width=0.6,color=brown
fx9 solid,line width=0.6,color=brown
fx10 solid,line width=0.6,color=brown
fx11 solid,line width=0.6,color=brown
fx12 solid,line width=0.6,color=brown

# fret labels
fl3 3
fl5 5
fl7 7
fl9 9
fl12 12

# string styles
sx1 solid,line width=0.5,color=black
sx2 solid,line width=0.55,color=black
sx3 solid,line width=0.6,color=black
sx4 solid,line width=0.65,color=black
sx5 solid,line width=0.7,color=black
sx6 solid,line width=0.75,color=black

# string labels
sl1 {\scriptsize e}
sl2 {\scriptsize B}
sl3 {\scriptsize G}
sl4 {\scriptsize D}
sl5 {\scriptsize A}
sl6 {\scriptsize E}

# # note notation: <string,fret>
# # barre notation: <start_string-end_string,fret>
#
# # A major triad barre chord
#
# barres <1-6,5>
# bx<1-6,5> fill=black, draw=black
#
# notes <6,5> <3,6> <4,7> <5,7> <2,5> <1,5>
#
# nx<6,5> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
# nl<6,5> {\scriptsize A}
#
# nx<5,7> shape=circle,draw=red,text=blue,fill=white,inner sep=1.7
# nl<5,7> {\scriptsize E}
#
# nx<4,7> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
# nl<4,7> {\scriptsize A}
#
# nx<3,6> shape=circle,draw=red,text=blue,fill=white,inner sep=0.3
# nl<3,6> {\scriptsize C$\sharp$}
#
# nx<2,5> shape=circle,draw=red,text=blue,fill=white,inner sep=1.7
# nl<2,5> {\scriptsize E}
#
# nx<1,5> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
# nl<1,5> {\scriptsize A}]]

local FP_STYLE_TEMPLATE = [[lC {\scriptsize C}
lC# {\tiny C$\sharp$}
lD {\scriptsize D}
lEb {\tiny E$\flat$}
lE {\scriptsize E}
lF {\scriptsize F}
lF# {\tiny F$\sharp$}
lG {\scriptsize G}
lAb {\tiny A$\flat$}
lA {\scriptsize A}
lBb {\tiny B$\flat$}
lB {\scriptsize B}

xC shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xC# shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xD shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xEb shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xE shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xF shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xF# shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xG shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xAb shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xA shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xBb shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xB shape=circle,draw=red,text=blue,fill=white,inner sep=1.0

l1 {\scriptsize 1}
lb2 {\tiny $\flat$2}
l2 {\scriptsize 2}
lb3 {\tiny $\flat$3}
l3 {\scriptsize 3}
l4 {\scriptsize 4}
lb5 {\tiny $\flat$5}
l5 {\scriptsize 5}
lb6 {\tiny $\flat$6}
l6 {\scriptsize 6}
lb7 {\tiny $\flat$7}
l7 {\scriptsize 7}

x1 shape=circle,draw=red,text=white,fill=red,inner sep=1.0
xb2 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
x2 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xb3 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
x3 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
x4 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xb5 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
x5 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xb6 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
x6 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
xb7 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0
x7 shape=circle,draw=red,text=blue,fill=white,inner sep=1.0]]

local FP_TEMPLATE_DEFAULT_PATH = "template.fp"
local FP_STYLE_TEMPLATE_DEFAULT_PATH = "template.fps"

local function write_fretplot_template(out_path)
   if out_path == "" then
      out_path = FP_TEMPLATE_DEFAULT_PATH
   end

   strtopath(out_path, FP_TEMPLATE)
end

local function write_fretplot_scale_style_template(out_path)
   if out_path == "" then
      out_path = FP_STYLE_TEMPLATE_DEFAULT_PATH
   end

   strtopath(out_path, FP_STYLE_TEMPLATE)
end

---

return {
   fptotikz = fretplot_to_tikz,
   fpscale = fpscale_tex_macro_functionality,
   fptemplate = write_fretplot_template,
   fpstemplate = write_fretplot_scale_style_template
}
