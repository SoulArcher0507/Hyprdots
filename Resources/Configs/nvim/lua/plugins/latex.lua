-- LaTeX
return {
    {
      "lervag/vimtex",
      lazy = false, -- lazy-loading will disable inverse search
      config = function()
        vim.g.vimtex_view_general_viewer = 'okular'
        --vim.g.vimtex_view_general_options = '--unique file:@pdf\\#src:@line@tex'
        vim.g.vimtex_compiler_latexmk = {
        aux_dir = "./.latexmk/aux",
        out_dir = "./.latexmk/out",
        
        vim.keymap.set("n", "<leader>lc", ":VimtexCompile<cr>")
      }
      end,
      keys = {
        { "<localLeader>l", "", desc = "+vimtex" },
      },
    }
}
