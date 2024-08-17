function! CompileInputComplete(ArgLead, CmdLine, CursorPos)
	let HasNoSpaces = a:CmdLine =~ '^\S\+$'
	let Results = getcompletion('!' . a:CmdLine, 'cmdline')
	let TransformedResults = map(Results, 'HasNoSpaces ? v:val : a:CmdLine[:strridx(a:CmdLine, " ") - 1] . " " . v:val')
	return TransformedResults
endfunction
