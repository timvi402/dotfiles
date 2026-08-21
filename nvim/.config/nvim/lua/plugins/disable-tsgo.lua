return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      -- Prevent Mason from auto-enabling tsgo alongside ts_ls for TS buffers.
      opts.servers.tsgo = {
        enabled = false,
      }
    end,
  },
}
