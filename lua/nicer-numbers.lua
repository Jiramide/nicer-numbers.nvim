---@class nicer-numbers.config
---@field languages table<string, LanguageNumberNode>
---@field default_number_nodes LanguageNumberNode

---@class nicer-numbers.main
local M = {}

---@class (exact) LanguageNumberNode
---@field integer string The treesitter node name for integer literals
---@field float string The treesitter node name for floating point literals
---@field has_distinct_floating_node boolean Whether a language distinguishes between integer and floating literals

---Produces the treesitter query for a given language node
---@param language_node LanguageNumberNode
local function get_number_query(language_node)
  if language_node.has_distinct_floating_node then
    return ("(%s) @integer (%s) @float"):format(language_node.integer, language_node.float)
  else
    return ("(%s) @integer"):format(language_node.integer)
  end
end

local function update_number_signs(args)
  local bufnr = args.buf
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok == false then
    return
  end

  local language = parser:lang()
  local number_nodes = M.get_language_number_nodes(language)

  local top_line = vim.fn.line("w0")
  local bot_line = vim.fn.line("w$")

  local query = get_number_query(number_nodes)
  local ok, number_query = pcall(vim.treesitter.query.parse, language, query)

  if ok == false then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, M.extmarks_ns, top_line, bot_line)

  parser:for_each_tree(function(tree)
    for _, node, _, _ in number_query:iter_captures(tree:root(), bufnr, top_line, bot_line) do
      local text = vim.treesitter.get_node_text(node, bufnr)

      ---@type table<integer, string?>
      local number_parts = vim.split(text, ".", { plain = true })
      local integral = assert(number_parts[1], "something went wrong! there should be something here!")
      local floating = number_parts[2]

      if integral:match("_") == nil then
        -- Integer portion isn't already delimited.
        local start_row, start_col = node:range()

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
        local start_row, start_col = node:range()
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
---@return LanguageNumberNode
function M.get_language_number_nodes(language)
  local number_nodes = M.cfg.languages[language]
  if number_nodes ~= nil then
    return number_nodes
  end

  return M.cfg.default_number_nodes
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
