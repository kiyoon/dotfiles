-- Remeber to run :KanagawaCompile
require("kanagawa").setup {
  compile = false,
  theme = {
    -- change specific usages for a certain theme, or for all of them
    wave = {
      ui = {
        float = {
          bg = "none",
        },
      },
    },
  },
  overrides = function(colors) -- add/modify highlights
    return {
      -- DiagnosticVirtualTextError = { fg = colors.palette.samuraiRed },
      -- DiagnosticVirtualTextWarn = { fg = colors.palette.roninYellow },
      -- DiagnosticVirtualTextInfo = { fg = colors.palette.waveAqua1 },
      -- DiagnosticVirtualTextHint = { fg = colors.palette.dragonBlue },
      --
      -- BufferCurrent = { bg = colors.palette.sumiInk4 },
      -- BufferCurrentTarget = { fg = colors.palette.autumnRed, bg = colors.palette.sumiInk4 },
      -- BufferCurrentSign = { bg = colors.palette.sumiInk4 },
      -- BufferCurrentMod = { fg = colors.palette.roninYellow, bg = colors.palette.sumiInk4 },
      -- BufferInactive = { bg = colors.palette.sumiInk4 },
      -- BufferInactiveTarget = { fg = colors.palette.autumnRed, bg = colors.palette.sumiInk4 },
      -- BufferInactiveSign = { bg = colors.palette.sumiInk4 },
      -- BufferInactiveMod = { fg = colors.palette.roninYellow, bg = colors.palette.sumiInk4 },
      --
      -- IndentBlanklineChar = { fg = colors.palette.sumiInk4 },
      -- HLInclineNormal = { bg = colors.palette.fujiWhite, fg = colors.palette.sumiInk0 },
      -- HLInclineNormalNC = { bg = colors.palette.sumiInk4, fg = colors.palette.fujiWhite },

      LeapBackdrop = { fg = colors.fg_comment },
      LeapLabelPrimary = { bold = true, fg = colors.fg_dark },
      LeapLabelSecondary = { bold = true, fg = colors.fg },
      LeapMatch = { bg = colors.bg_search, bold = true, fg = colors.fg },
      -- LeapLabelPrimary = { fg = colors.palette.sumiInk0, bg = colors.palette.autumnRed },
      -- LeapLabelSecondary = { fg = colors.palette.sumiInk0, bg = colors.palette.autumnYellow },

      NeoTreeIndentMarker = { link = "IndentBlanklineChar" },

      NvimTreeRootFolder = { fg = colors.palette.autumnYellow },
      NvimTreeOpenedFolderName = { fg = colors.palette.dragonBlue },

      JupyniumCodeCellSeparator = { bg = colors.palette.winterYellow },
      JupyniumMarkdownCellSeparator = { bg = colors.palette.winterRed },
      JupyniumMarkdownCellContent = { bg = colors.palette.sumiInk4 },
      JupyniumMagicCommand = { link = "Keyword" },

      ScrollbarCursor = { fg = colors.palette.oldWhite },
      WhichKey = { fg = colors.palette.peachRed },
      YankyYanked = { bg = colors.palette.winterYellow },
      YankyPut = { bg = colors.palette.winterRed },
    }
  end,
}
