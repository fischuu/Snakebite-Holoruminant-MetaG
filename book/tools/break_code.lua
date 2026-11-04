-- Let inline code break across lines in the PDF. Names like fischuu/hrp_assemble:0.2 or
-- assemble__magscot__merge_contig_to_bin have no spaces, so LaTeX can't wrap them, and in a table
-- they then print over the next column. This allows a break after / _ : . - and =.
-- Headings stay as they are, as they also go into the table of contents.

local special = {
  ["\\"] = "\\textbackslash{}",
  ["{"] = "\\{",
  ["}"] = "\\}",
  ["$"] = "\\$",
  ["&"] = "\\&",
  ["#"] = "\\#",
  ["%"] = "\\%",
  ["^"] = "\\textasciicircum{}",
  ["~"] = "\\textasciitilde{}",
  ["'"] = "\\textquotesingle{}",
  ["`"] = "\\textasciigrave{}",
  ['"'] = "\\textquotedbl{}",
  ["|"] = "\\textbar{}",
  ["<"] = "\\textless{}",
  [">"] = "\\textgreater{}",
  ["_"] = "\\_\\allowbreak{}",
  ["/"] = "/\\allowbreak{}",
  [":"] = ":\\allowbreak{}",
  ["."] = ".\\allowbreak{}",
  ["-"] = "-{}\\allowbreak{}",
  ["="] = "=\\allowbreak{}",
  [","] = ",\\allowbreak{}",
  ["("] = "(\\allowbreak{}",
  ["["] = "{[}\\allowbreak{}",
  ["]"] = "{]}\\allowbreak{}",
  ["@"] = "@\\allowbreak{}",
}

return {
  {
    traverse = "topdown",
    Header = function(header)
      return header, false
    end,
    -- A code block without a language can't wrap in LaTeX. As "text", it wraps and looks like the others.
    CodeBlock = function(block)
      if FORMAT:match("latex") and #block.classes == 0 then
        block.classes = { "text" }
        return block
      end
    end,
    Code = function(code)
      if not FORMAT:match("latex") then
        return nil
      end
      local text = code.text:gsub(".", function(char)
        return special[char]
      end)
      return pandoc.RawInline("latex", "\\texttt{" .. text .. "}")
    end,
  },
}
