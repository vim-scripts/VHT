" HTML templates
" Author: Mikolaj Machowski ( mikmach AT wp DOT pl )
"
" License: GPL v. 2.0
" Version: 1.0
" Last_change: 15 May 2004
" 
" Replica of DreamWeaver(tm) templates.
" Somewhere in file hierarchy exists .vht file which is
" template for all files in current file tree. Areas of
" modifications are marked by
" <!-- #BeginEditable "regionname" -->
" <!-- #EndEditable -->
" tags.
"
" Plugin makes possible to write locally made modifications
" to template and update template without losing changes in Editable
" areas. And change all links to make them local.
"
" TODO?
" - automation of update/commit with BufEnter/BufWrite

" ======================================================================
" Commands
" ======================================================================

command! -nargs=? VHTcommit call VHT_Commit(<q-args>)
command! -nargs=? VHTupdate call VHT_Update(<q-args>)
command! -nargs=? VHTcheckout call VHT_Checkout(<q-args>)

command! -nargs=? VHLcommit call VHL_Commit(<q-args>)
command! -nargs=? VHLupdate call VHL_Update(<q-args>)
command! -nargs=? VHLcheckout call VHL_Checkout(<q-args>)

" ======================================================================
" Main functions
" ======================================================================
" VHT_Commit: responsible for writing noneditable area to .vht file {{{
" Description: Write file line by line to register, skipping editable
" 		areas, then overwriting .vht file. Meantime it will extract
" 		links and change them to fullpaths ":p".
function! VHT_Commit(tmplname)

	" Check the most important thing about templates: is a storage place
	" for them?
	let vhtlevel = VHT_GetMainFileName(":p:h")
	if isdirectory(vhtlevel.'/Templates/') != 0
		let vhtdir = vhtlevel.'/Templates/'
	else
		echomsg "VHT: Templates directory doesn't exist. Create it!"
		return
	endif
		
	" Save current position
	let scol = col('.')
	let sline = line('.')

	let curd = getcwd()
	let filedir = expand('%:p:h')
	" change to dir where is file to get proper extension of relative
	" filenames
	call VHT_CD(filedir)

	normal! gg
	let editable = 0
	let z_rez = @z
	let @z = ''
	while line('.') <= line('$')
		let line = getline('.')
		if editable == 1 && line !~ '<!--\s*#EndEditable.*-->'
			normal! j
			continue
		endif
		if line =~ '<!--\s*#BeginEditable.*-->'
			let editable = 1
		endif
		if line =~ '<!--\s*#EndEditable.*-->'
			let editable = 0
		endif

		" Check if in line are links, when positive expand them to full
		" paths
		let line = VHT_ExpandLinks(line)

		" Prevent inserting blank line at the beginning
		if @z == ''
			let @z = line
		else
			let @z = @z."\n".line
		endif

		" Service last line without infinite loop
		if line('.') == line('$')
			break
		endif

		normal! j
	endwhile

	" Put contents of @z to template file. Find .htmlmain to check where
	" Templates is dir for them - following Dreamweaver.
	" Let check if argument exists or name of template was previously
	" set. This will enable use of multiply templates in one project. 
	if a:tmplname != ''
		let vhtfile = vhtdir.a:tmplname.'.vht'
		let b:vhtemplate = a:tmplname

	elseif exists("b:vhtemplate") && a:tmplname == ''
		let vhtfile = vhtdir.b:vhtemplate.'.vht'

	else
		let vhtname = input("You didn't specify Template name.\n".
				   \   "Enter name of existing template -\n".
				   \   VHT_ListFiles(vhtdir, "vht").
				   \   "\nOr a new one (<Enter> to abandon action): ")

		if vhtname != ''
			let b:vhtemplate = vhtname
			let vhtfile = vhtdir.b:vhtemplate.'.vht'
		else

			call cursor(sline, scol)
			return
		endif

	endif

	exe "below 1split ".vhtfile
	silent normal! gg"_dG
	silent put! z
	write
	exe "bwipe ".vhtfile
	let @z = z_rez

	" Return to current dir
	call VHT_CD(curd)

	if getline('$') == ''
		silent $d
	endif

	call cursor(sline, scol)

endfunction

" }}}
" VHT_Checkout: 0read in template to current file {{{
" Description: Locate template and read in to the current file. Also
" 		correct links. It assumes file is empty!
function! VHT_Checkout(tmplname)
	" Check the most important thing about templates: is a storage place
	" for them?
	let vhtlevel = VHT_GetMainFileName(":p:h")
	if isdirectory(vhtlevel.'/Templates/') != 0
		let vhtdir = vhtlevel.'/Templates/'
	else
		echomsg "VHT: Templates directory doesn't exist. Create it!"
		return
	endif

	" Put contents of @z to template file. Find .htmlmain to check where
	" Templates is dir for them - following Dreamweaver.
	" Let check if argument exists or name of template was previously
	" set. This will enable use of multiply templates in one project. 
	if a:tmplname != ''
		let vhtfile = vhtdir.a:tmplname.'.vht'
		let b:vhtemplate = a:tmplname

	elseif exists("b:vhtemplate") && a:tmplname == ''
		let vhtfile = vhtdir.b:vhtemplate.'.vht'

	else
		let vhtname = input("You didn't specify Template name.\n".
				   \   "Enter name of template -\n".
				   \   VHT_ListFiles(vhtdir, 'vht').
				   \   "\n(<Enter> to abandon action): ")

		if vhtname != ''
			let b:vhtemplate = vhtname
			let vhtfile = vhtdir.b:vhtemplate.'.vht'

		else
			return

		endif

	endif

	exe 'silent 0read '.vhtfile

	let curd = getcwd()
	let filedir = expand('%:p:h')
	" change to dir where is file to get proper extension of relative
	" filenames
	call VHT_CD(filedir)

	normal! gg

	let z_rez = @z
	let @z = ''

	while line('.') <= line('$')

		let line = getline('.')

		if line =~? '\(href\|src\)\s*='
			let link = matchstr(line, "\\(href\\|src\\)\\s\*=\\s\*\\('\\|\"\\)\\zs.\\{-}\\ze\\2")
			if link !~ '^\(https\?\|s\?ftp\|\#\|javascript:\|mailto:\)'
				let rellink = VHT_RelPath(link, expand('%:p'))
				" Now. Replace old name with new one... s/// and
				" substitute() ma be tricky because of special chars.
				" escape()? What chars should be escaped?
				let esclink = escape(link, ' \.?')
				let escrellink = escape(rellink, ' \.?')
				let line = substitute(line, esclink, escrellink, 'ge')
			endif
		endif

		" Prevent inserting blank line at the beginning
		if @z == ''
			let @z = line
		else
			let @z = @z."\n".line
		endif

		" Service last line without infinite loop
		if line('.') == line('$')
			break
		endif

		normal! j
	endwhile

	" Return to current dir
	call VHT_CD(curd)

	" Delete file and put @z content
	silent normal! gg"_dG
	silent put! z

	let @z = z_rez

	if getline('$') == ''
		silent $d
	endif

	normal! gg

endfunction

" }}}
" VHT_Update: update template area preserving changes in Editable {{{
" Description: Save editable areas to variables/registers/temporary
" 		files, remove file, checkout template, paste editables into
" 		proper places.
function! VHT_Update(tmplname)

	" Check the most important thing about templates: is a storage place
	" for them?
	let vhtlevel = VHT_GetMainFileName(":p:h")
	if isdirectory(vhtlevel.'/Templates/') != 0
		let vhtdir = vhtlevel.'/Templates/'
	else
		echomsg "VHT: Templates directory doesn't exist. Create it!"
		return
	endif


	let scol = col('.')
	let sline = line('.')

	let z_rez = @z

	normal! gg

	while search('<!--\s*#BeginEditable .*-->', 'W')
		let regname = matchstr(getline('.'), '<!--\s*#BeginEditable\s*"\zs.\{-}\ze"')
		if getline(line('.')+1) !~ '<!--\s*#EndEditable ' 
			:silent .+1,/<!--\s*#EndEditable /-1 y z
		else
			continue
		endif
		exe 'let b:vht_'.regname.' = @z'

	endwhile

	silent normal! gg"_dG

	call VHT_Checkout(a:tmplname)

	while search('<!--\s*#BeginEditable .*-->', 'W')
		let regname = matchstr(getline('.'), '<!--\s*#BeginEditable\s*"\zs.\{-}\ze"')
		if exists("b:vht_".regname)
			exe 'let @z = b:vht_'.regname
			silent put z
		endif

	endwhile

	let @z = z_rez

	if getline('$') == ''
		silent $d
	endif

	call cursor(sline, scol)

endfunction
" }}}

" VHL_Commit: commit current/last library to repository {{{
" Description: Find last BeginLibraryItem and put whole area between
" tags to file described in argument of start tag
function! VHL_Commit(libitem)

	let vhllevel = VHT_GetMainFileName(":p:h")

	" Save current position
	let scol = col('.')
	let sline = line('.')

	if a:libitem == 'all'
		normal! gg
	    while search('<!--\s*#BeginLibraryItem ', 'W')
			call VHL_Commit('')
		endwhile
		call cursor(sline, scol)
		return
	endif


	" If we start on BeginLibraryItem make sure to include it
	normal! j

	let line = search('<!--\s*#BeginLibraryItem ', 'bW')

	if line == 0
		call cursor(sline, scol)
		return
	endif

	let curd = getcwd()
	let filedir = expand('%:p:h')
	" change to dir where is file to get proper extension of relative
	" filenames
	call VHT_CD(filedir)

	let z_rez = @z
	let @z = ''

	let libname = matchstr(getline('.'), '<!--\s*#BeginLibraryItem\s*"\zs.\{-}\ze"')
	if libname[0] == '~'
		let vhlfile = fnamemodify(libname, ':p')
	elseif libname[0] !~ '[\/]'
		let vhlfile = vhllevel.'/'.libname
	else
		let vhlfile = vhllevel.libname
	endif

	silent normal! j

	while getline('.') !~ '<!--\s*#EndLibraryItem '

		" Check if in line are links, when positive expand them to full
		" paths
		let curline = VHT_ExpandLinks(getline('.'))

		" Prevent inserting blank line at the beginning
		if @z == ''
			let @z = curline
		else
			let @z = @z."\n".curline
		endif

		silent normal! j

	endwhile

	if filewritable(vhlfile) == 0
		" Hmm. Maybe this is new Lib?
		if filewritable(fnamemodify(vhlfile, ":p:h")) == 2
			" OK. Directory exists, just file isn't there. Proceed.
			exe 'silent below 1split '.vhlfile
			silent put! z
			silent $d
			silent write!
			exe 'bwipe '.vhlfile

		else
			" Something is wrong with pathname. Abort! Abort! Abort!
			echomsg "VHL: Can't write to or create Library with this path."

		endif

	else
		" Library already exist, we need to update its contents with @z
		let g:lfile = vhlfile
		exe 'silent below 1split '.vhlfile
		silent normal! gg"_dG
		silent put! z
		silent $d
		silent write!
		exe 'bwipe '.vhlfile

	endif

	let @z = z_rez

	call VHT_CD(curd)

	call cursor(sline, scol)

endfunction
"
" }}}
" VHL_Update: Update contents of current/lost library in file. {{{
" Description: Find last BeginLibraryItem and update area between tags
" tags to file described in argument of start tag
function! VHL_Update(libitem)

	let vhllevel = VHT_GetMainFileName(":p:h")

	" Save current position
	let scol = col('.')
	let sline = line('.')

	if a:libitem == 'all'
		normal! gg
	    while search('<!--\s*#BeginLibraryItem ', 'W')
			call VHL_Update('')
		endwhile
		call cursor(sline, scol)
		return
	endif

	" If we start on BeginLibraryItem make sure to include it
	normal! j

	let curd = getcwd()
	let filedir = expand('%:p:h')
	" change to dir where is file to get proper extension of relative
	" filenames
	call VHT_CD(filedir)

	" First we have to find if LibItem exists.
	let line = search('<!--\s*#BeginLibraryItem ', 'bW')

	" End if there is no LibItem above
	if line == 0
		call cursor(sline, scol)
		return
	endif

	let libname = matchstr(getline('.'), '<!--\s*#BeginLibraryItem\s*"\zs.\{-}\ze"')
	if libname !~ '^[\/]'
		let libname = '/'.libname
	endif

	let vhlfile = vhllevel.libname

	if filewritable(vhlfile) == 0
		" Something is wrong with pathname. Abort now!
		call VHT_CD(curd)
		call cursor(sline, scol)
		echomsg "VHL: Can't find this Library - check path."

		return

	endif

	" When we know LibItem exists we can remove current lib.
	if getline(line('.')+1) !~ '<!--\s*#EndLibraryItem ' 
		silent .+1,/<!--\s*#EndLibraryItem /-1 d _
	endif
	" Make sure we are back at the line with BeginLibraryItem
	exe line
	exe 'silent read '.vhlfile

	" Change links in Library from full to relative
	call VHT_CollapseLibLinks()

	call VHT_CD(curd)
	call cursor(sline, scol)

endfunction
"
" }}}
" VHL_Checkout: put at cursor position contents of library {{{
" Description: Find Library and put chosen snippet into cursor position
" 	(with links parsing)
function! VHL_Checkout(libitem)
	let vhllevel = VHT_GetMainFileName(":p:h")

	let sline = line('.')
	let scol = col('.')

	" Put contents of @z to template file. Find .htmlmain to check where
	" Templates is dir for them - following Dreamweaver.
	" Let check if argument exists or name of template was previously
	" set. This will enable use of multiply templates in one project. 
	if a:libitem != ''

		let vhlname = a:libitem

		if a:libitem[0] == '~'
			let vhlfile = fnamemodify(a:libitem, ':p')

		elseif a:libitem[0] != '/'
			let vhlfile = vhllevel.'/'.a:libitem

		endif

	else
		let vhlname = input("You didn't specify Library path.\n".
				   \   "Enter path to existing library -\n".
				   \   VHT_ListFiles(vhllevel, 'vhl').
				   \   "\n(<Enter> to abandon action): ")

		if vhlname != ''
			let vhlfile = vhllevel.'/'.vhlname

		else
			return

		endif

	endif

	if filereadable(vhlfile) != 1
		echomsg "VHL: Not correct path to Library. Try Again!"
		exe sline
		call cursor(sline, scol)
		return

	else
		exe 'silent below 1split '.vhlfile
		let z_rez = @z
		silent normal! gg"zyG
		let @z = '<!-- #BeginLibraryItem "'.vhlname.'" -->'."\n".@z."\n".
			\    '<!-- #EndLibraryItem -->'
		exe 'bwipe '.vhlfile
		exe sline
		silent put z
		let @z = z_rez

	endif

	let curd = getcwd()
	let filedir = expand('%:p:h')
	" change to dir where is file to get proper extension of relative
	" filenames
	call VHT_CD(filedir)

	" Make sure we are back at the beginning of Library content
	exe sline + 1

	" Change links in Library from full to relative
	call VHT_CollapseLibLinks()

	call VHT_CD(curd)
	call cursor(sline, scol)

endfunction
"
" }}}
" ======================================================================
" Auxiliary functions
" ======================================================================
" Many of these functions are coming from vim-latexSuite project
" 		http://vim-latex.sourceforge.net
" VHT_GetMainFileName: gets the name of the root html file. {{{
" Description:  returns the full path name of the main file.
"               This function checks for the existence of a .htmlmain file
"               which might point to the location of a "main" html file.
"               If .htmlmain exists, then return the full path name of the
"               file being pointed to by it.
"
"               Otherwise, return the full path name of the current buffer.
"
"               You can supply an optional "modifier" argument to the
"               function, which will optionally modify the file name before
"               returning.
"               NOTE: From version 1.6 onwards, this function always trims
"               away the .htmlmain part of the file name before applying the
"               modifier argument.
function! VHT_GetMainFileName(...)
	if a:0 > 0
		let modifier = a:1
	else
		let modifier = ':p'
	endif

	" If the user wants to use his own way to specify the main file name, then
	" use it straight away.
	if VHT_GetVarValue('VHT_MainFileExpression', '') != ''
		exec 'let retval = '.VHT_GetVarValue('VHT_MainFileExpression', '')
		return retval
	endif

	let curd = getcwd()

	let dirmodifier = '%:p:h'
	let dirLast = expand(dirmodifier)
	call VHT_CD(dirLast)

	" move up the directory tree until we find a .htmlmain file.
	" TODO: Should we be doing this recursion by default, or should there be a
	"       setting?
	while glob('*.htmlmain') == ''
		let dirmodifier = dirmodifier.':h'
		" break from the loop if we cannot go up any further.
		if expand(dirmodifier) == dirLast
			break
		endif
		let dirLast = expand(dirmodifier)
		call VHT_CD(dirLast)
	endwhile

	let lheadfile = glob('*.htmlmain')
	if lheadfile != ''
		" Remove the trailing .htmlmain part of the filename... We never want
		" that.
		let lheadfile = fnamemodify(substitute(lheadfile, '\.htmlmain$', '', ''), modifier)
	else
		" If we cannot find any main file, just modify the filename of the
		" current buffer.
		let lheadfile = expand('%'.modifier)
	endif

	call VHT_CD(curd)

	" NOTE: The caller of this function needs to escape spaces in the
	"       file name as appropriate. The reason its not done here is that
	"       escaping spaces is not safe if this file is to be used as part of
	"       an external command on certain platforms.
	return lheadfile
endfunction 
" }}}
" VHT_CD: cds to given directory escaping spaces if necessary {{{
" " Description: 
function! VHT_CD(dirname)
	exec 'cd '.VHT_EscapeSpaces(a:dirname)
endfunction " }}}
" VHT_EscapeSpaces: escapes unescaped spaces from a path name {{{
" Description:
function! VHT_EscapeSpaces(path)
	return substitute(a:path, '[^\\]\(\\\\\)*\zs ', '\\ ', 'g')
endfunction " }}}
" VHT_GetVarValue: gets the value of the variable {{{
" Description: 
" 	See if a window-local, buffer-local or global variable with the given name
" 	exists and if so, returns the corresponding value. Otherwise return the
" 	provided default value.
function! VHT_GetVarValue(varname, default)
	if exists('w:'.a:varname)
		return w:{a:varname}
	elseif exists('b:'.a:varname)
		return b:{a:varname}
	elseif exists('g:'.a:varname)
		return g:{a:varname}
	else
		return a:default
	endif
endfunction " }}}
" VHT_Common: common part of strings {{{
function! s:VHT_Common(path1, path2)
	" Assume the caller handles 'ignorecase'
	if a:path1 == a:path2
		return a:path1
	endif
	let n = 0
	while a:path1[n] == a:path2[n]
		let n = n+1
	endwhile
	return strpart(a:path1, 0, n)
endfunction " }}}
" VHT_NormalizePath:  {{{
" Description: 
function! VHT_NormalizePath(path)
	let retpath = a:path
	if has("win32") || has("win16") || has("dos32") || has("dos16")
		let retpath = substitute(retpath, '\\', '/', 'ge')
	endif
	if isdirectory(retpath) && retpath !~ '/$'
		let retpath = retpath.'/'
	endif
	return retpath
endfunction " }}}
" VHT_RelPath: ultimate file name {{{
function! VHT_RelPath(explfilename,texfilename)
	let path1 = VHT_NormalizePath(a:explfilename)
	let path2 = VHT_NormalizePath(a:texfilename)

	let n = matchend(<SID>VHT_Common(path1, path2), '.*/')
	let path1 = strpart(path1, n)
	let path2 = strpart(path2, n)
	if path2 !~ '/'
		let subrelpath = ''
	else
		let subrelpath = substitute(path2, '[^/]\{-}/', '../', 'ge')
		let subrelpath = substitute(subrelpath, '[^/]*$', '', 'ge')
	endif
	let relpath = subrelpath.path1
	return escape(VHT_NormalizePath(relpath), ' ')
endfunction " }}}
" ----------------------------------------------------------------------
" VHT_ListFiles: give list of templates or libraries {{{
" Description: cd to template/library dir and get list of files, remove
" extensions
function! VHT_ListFiles(vhtdir, ext)
	let curd = getcwd()
	call VHT_CD(a:vhtdir)
	if a:ext == 'vht'
		let filelist = glob("*")
		let filelist = substitute(filelist, '\.vht', '', 'ge')
	elseif a:ext == 'vhl'
		let filelist = globpath(".,Library", '*.\(vhl\|lbi\)')
		let filelist = substitute(filelist, '\(^\|\n\)\..', '\1', 'ge')
	endif
	call VHT_CD(curd)
	return filelist
endfunction

" }}}
" VHT_CollapseLibLinks: Change full paths of Library links to relative {{{
" Description: go through read file up to End LibraryItem and change
" links
function! VHT_CollapseLibLinks()
	" Update links in read file - up to EndLibraryItem
	while getline('.') !~ '<!--\s*#EndLibraryItem '
		if getline('.') =~? '\(href\|src\)\s*='
			let link = matchstr(getline('.'), "\\(href\\|src\\)\\s\*=\\s\*\\('\\|\"\\)\\zs.\\{-}\\ze\\2")
			if link !~ '^\(https\?\|s\?ftp\|\#\|javascript:\|mailto:\)'
				let rellink = VHT_RelPath(link, expand('%:p'))
				" Now. Replace old name with new one... s/// and
				" substitute() ma be tricky because of special chars.
				" escape()? What chars should be escaped?
				let esclink = escape(link, ' \.?')
				let escrellink = escape(rellink, ' \.?')
				exe 'silent s+'.esclink.'+'.escrellink.'+ge'
			endif
		endif

		normal! j

	endwhile

endfunction

" }}}
" VHT_ExpandLinks: Change names in links from relative to full path {{{
" Description: take line and change names if necessary
function! VHT_ExpandLinks(line)

	let line = a:line

	if line =~? '\(href\|src\)\s*='
		let link = matchstr(line, "\\(href\\|src\\)\\s\*=\\s\*\\('\\|\"\\)\\zs.\\{-}\\ze\\2")
		if link !~ '^\(https\?\|s\?ftp\|\#\|javascript:\|mailto:\)'
			let fulllink = fnamemodify(link, ":p")
			" Now. Replace old name with new one... s/// and
			" substitute() ma be tricky because of special chars.
			" escape()? What chars should be escaped?
			" let esclink = escape(link, ' \.?')
			let escfulllink = escape(fulllink, ' \.?')
			let line = substitute(line, link, escfulllink, 'ge')
		endif
	endif

	return line

endfunction

" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4:nowrap
