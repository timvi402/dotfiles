return {
  'mg979/vim-visual-multi',
  branch = 'master',
  init = function()
    -- disable default mappings if you want a clean slate
    vim.g.VM_default_mappings = 0

    -- define your own maps
    vim.g.VM_maps = {
      ['Find Under'] = '<C-d>',
      ['Find Subword Under'] = '<C-d>',
      -- you can add more custom maps here if you like
    }
  end,
}
