return {
  -- Install biome via mason
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "biome" })
    end,
  },

  -- Configure biome as LSP server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        biome = {},
      },
    },
  },

  -- Use biome for formatting JS/TS/JSON files
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      -- Increase timeout for large files (default 1000ms is too low for big JSON)
      opts.default_format_opts = vim.tbl_deep_extend("force", opts.default_format_opts or {}, {
        timeout_ms = 5000,
      })

      -- Override the built-in condition that requires a biome.json in the project
      opts.formatters.biome = {
        condition = function()
          return true
        end,
      }

      local biome_filetypes = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "json",
        "jsonc",
      }
      for _, ft in ipairs(biome_filetypes) do
        opts.formatters_by_ft[ft] = { "biome", "jq", stop_after_first = true }
      end
      return opts
    end,
  },
}
