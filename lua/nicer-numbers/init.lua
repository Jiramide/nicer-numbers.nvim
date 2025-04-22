---@class nicer-numbers.main
local M = {}

---@class (exact) LanguageNumberNode
---@field integer string The treesitter node name for integer literals
---@field float string The treesitter node name for floating point literals
---@field has_distinct_floating_node boolean Whether a language distinguishes between integer and floating literals

---Produces the treesitter query for a given language node
---@param language_cfg LanguageConfig
local function get_number_query(language_cfg)
  local collected_node_types = {}

  for _, node_type in ipairs(language_cfg.nodes) do
    table.insert(collected_node_types, ("(%s)"):format(node_type))
  end

  return ("[%s] @nicer-numbers"):format(collected_node_types)
end

local function update_number_signs(args)
  local bufnr = args.buf
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok == false then
    return
  end

  -- vim.fn.line uses 1-based indexing, but treesitter uses 0-based indexing.
  local top_line = vim.fn.line("w0") - 1
  local bot_line = vim.fn.line("w$") - 1

  vim.api.nvim_buf_clear_namespace(bufnr, M.extmarks_ns, top_line, bot_line)

  parser:for_each_tree(function(tree, lang_tree)
    local language = lang_tree:lang()
    local language_cfg = M.get_language_number_nodes(language)

    local query = get_number_query(language_cfg)
    local ok, number_query = pcall(vim.treesitter.query.parse, language, query)

    if ok == false then
      return
    end

    for _, node, _, _ in number_query:iter_captures(tree:root(), bufnr, top_line, bot_line) do
      local text = vim.treesitter.get_node_text(node, bufnr)
      local type = node:type()
      local start_row, start_col = node:range()

      local offsets = language_cfg.delimit_fn(text, type)
      for _, offset in pairs(offsets) do
        local col = start_col + offset
        vim.api.nvim_buf_set_extmark(0, M.extmarks_ns, start_row, col, {
          virt_text_pos = "inline",
          virt_text = { { "_", "Number" } },
          invalidate = true,
        })
      end

      ---@type table<integer, string?>
      local number_parts = vim.split(text, ".", { plain = true })
      local integral = assert(number_parts[1], "something went wrong! there should be something here!")
      local floating = number_parts[2]

      if integral:match("_") == nil then
        -- Integer portion isn't already delimited.
        local starting_offset = #integral % 3
        if starting_offset == 0 then
          starting_offset = starting_offset + 3
        end

        for offset = starting_offset, #integral - 3, 3 do
          local col = start_col + offset
          vim.api.nvim_buf_set_extmark(0, M.extmarks_ns, start_row, col, {
            virt_text_pos = "inline",
            virt_text = { { "_", "Number" } },
            invalidate = true,
          })
        end
      end

      if floating ~= nil and floating:match("_") == nil then
        -- Integer portion isn't already delimited.
        -- shift by length of integral portion, plus one (for decimal point)
        local floating_offset = #integral + 1

        local starting_offset = #floating % 3
        if starting_offset == 0 then
          starting_offset = starting_offset + 3
        end

        for offset = 3, #floating - 1, 3 do
          local col = start_col + floating_offset + offset
          vim.api.nvim_buf_set_extmark(0, M.extmarks_ns, start_row, col, {
            virt_text_pos = "inline",
            virt_text = { { "_", "Number" } },
            invalidate = true,
          })
        end
      end
    end
  end)
end

---Produces the language node for a given language
---@param language string
---@return LanguageConfig
function M.get_language_number_nodes(language)
  local number_nodes = M.cfg.languages[language]

  if number_nodes ~= nil then
    return number_nodes
  end

  return M.cfg.default
end

---@param cfg nicer-numbers.config
function M.setup(cfg)
  M.autocmd_ns = vim.api.nvim_create_namespace("nicer-numbers-autocmd-ns")
  M.extmarks_ns = vim.api.nvim_create_namespace("nicer-numbers-extmarks-ns")
  M.cfg = cfg

  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "WinScrolled" }, {
    callback = update_number_signs,
  })
end

return M
