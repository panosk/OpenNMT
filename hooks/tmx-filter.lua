require('xmlreader')

local tmx_file = arg[1] -- the tmx file 
local src_lang = arg[2] -- the source language code (e.g. "en", "el")
local tgt_lang = arg[3] -- the target language code

local xmldoc = assert(xmlreader.from_file(tmx_file))

local myopt =
{
  {
    '-tmx_filepath', '',
    [[The TMX file from which to create two text files for training.]]    
  },
  {
    '-src_lang', '',
    [[Code map the source language. Valid codes are "en", "fr", etc.]]
  },
  {
    '-tgt_lang', '',
    [[Code map the target language. Valid codes are "en", "fr", etc.]]
  },
  {
    '-src_file', '',
    [[Append the source segments to an existing file.]]
  },
  {
    '-tgt_file', '',
    [[Append the target segments to an existing file.]]
  }
}

local function declareOptsFn(cmd)
  cmd:setCmdLineOptions(myopt, 'Preprocessor')
end

local srcfile = paths.basename(tmx_file, "tmx") .. ".temp." .. src_lang
local tgtfile = paths.basename(tmx_file, "tmx") .. ".temp." .. tgt_lang

local src_file = io.open(srcfile, "a")
local tgt_file = io.open(tgtfile, "a")

local function write_segments(language_pairs)
  for k, v in pairs(language_pairs) do
    if k == src_lang then
      src_file:write(v, "\n")
    else
      tgt_file:write(v, "\n")
    end
  end
end

local function get_segment()
  local segment
  while (xmldoc:read()) do
    if (xmldoc:node_type() == "element" and xmldoc:name() == "seg") then
      segment = xmldoc:read_string()
      if segment ~= nil then
        segment = segment:gsub("\n","")
      end
      break
    end
  end
  return segment
end

local function process_tu()
  local segments = {}
  while (xmldoc:read() and not (xmldoc:node_type() == "end element" and xmldoc:name() == "tu")) do
    if (xmldoc:node_type() == "element" and  xmldoc:name() == "tuv") then
      -- Get only the base language code and lowercase it, e.g. "EN-US" -> "en"
      local lang = string.sub(xmldoc:xml_lang(), 1, 2):lower()
      if (lang == src_lang or lang == tgt_lang) then
        segments[lang] = get_segment() -- this assures that the table will always have only one segment per language
      end
    end
  end

  local counter = 0
  for k, v in pairs(segments) do
    counter = counter + 1
  end
  
  -- Last sanity check that we have one source and one target sentence
  if (counter == 2) then
    write_segments(segments)
    tuv_num = tuv_num + 1
    io.write("\rExtracted ", tuv_num, " translation units")
    io.flush()
  end
end

local function process_tmx()
  print("Processing file", tmx_file)
  local timer = os.time()
  tuv_num = 0
  while (xmldoc:read()) do
    if (xmldoc:node_type() == "element" and xmldoc:name() == "tu") then
      process_tu()
    end
  end
  xmldoc:close()
  src_file:close()
  tgt_file:close()
  io.write("\rExtracted " .. tuv_num .. " translation units in " .. os.difftime(os.time(), timer) .. " seconds")
  io.write("\n")
end

return process_tmx()
