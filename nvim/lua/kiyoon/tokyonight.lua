require("tokyonight").setup({
  style = "moon",
  transparent = true,
  styles = {
    sidebars = "transparent",
    floats = "transparent",
  },
  -- nvim-navic bg colour match with lualine.
  on_highlights = function(hl, c)
    hl.NavicIconsFile = { bg = c.bg_dark, fg = c.fg }
    hl.NavicIconsModule = { bg = c.bg_dark, fg = c.yellow }
    hl.NavicIconsNamespace = { bg = c.bg_dark, fg = c.fg }
    hl.NavicIconsPackage = { bg = c.bg_dark, fg = c.fg }
    hl.NavicIconsClass = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsMethod = { bg = c.bg_dark, fg = c.blue }
    hl.NavicIconsProperty = { bg = c.bg_dark, fg = c.green1 }
    hl.NavicIconsField = { bg = c.bg_dark, fg = c.green1 }
    hl.NavicIconsConstructor = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsEnum = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsInterface = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsFunction = { bg = c.bg_dark, fg = c.blue }
    hl.NavicIconsVariable = { bg = c.bg_dark, fg = c.magenta }
    hl.NavicIconsConstant = { bg = c.bg_dark, fg = c.magenta }
    hl.NavicIconsString = { bg = c.bg_dark, fg = c.green }
    hl.NavicIconsNumber = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsBoolean = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsArray = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsObject = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsKey = { bg = c.bg_dark, fg = c.purple }
    hl.NavicIconsNull = { bg = c.bg_dark, fg = c.purple }
    hl.NavicIconsEnumMember = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsStruct = { bg = c.bg_dark, fg = c.green1 }
    hl.NavicIconsEvent = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsOperator = { bg = c.bg_dark, fg = c.orange }
    hl.NavicIconsTypeParameter = { bg = c.bg_dark, fg = c.fg }
    hl.NavicText = { bg = c.bg_dark, fg = c.fg }
    hl.NavicSeparator = { bg = c.bg_dark, fg = c.fg }
  end,
})
