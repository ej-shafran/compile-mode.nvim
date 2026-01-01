function! CompileModeStatusline(Colors)
	return v:lua.require('compile-mode').statusline(a:Colors)
endfunction
