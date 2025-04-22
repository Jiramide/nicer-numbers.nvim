---@class nicer-numbers.config
---@field delimiter string
---@field languages table<string, LanguageConfig>
---@field default LanguageConfig

---@class (exact) LanguageConfig
---@field nodes string[]
---@field delimit_fn function(text: string, node_type: string): number[]

local Config = {}

---Produces a nicer-numbers configuration based off of given config
---@param cfg nicer-numbers.config
---@return nicer-numbers.config
function Config.build(cfg)
  return vim.deepcopy(Config.default, cfg)
end

return Config
