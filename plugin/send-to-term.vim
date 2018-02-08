if exists("g:loaded_sendtoterm")
  finish
endif
let g:loaded_sendtoterm = 1

" Parts specific to terminal destination
let g:send_multiline = get(g:, 'send_multiline', {})
let g:send_multiline.default = {'begin':'', 'end':"\n", 'newline':"\n"}
let g:send_multiline.ipy = {'begin':"\e[200~", 'end':"\e[201~\r\r\r", 'newline':"\n"}
" This works too:
" let g:send_multiline.ipy = {'begin':'', 'end':"\r\r\r", 'newline':"\<c-q>\n"}

function! s:SendHere(...)
    if !exists('b:terminal_job_id')
        echoerr 'This buffer is not a terminal.'
        return
    end

    let term_type = get(a:000, 0, 'default')
    let g:send_target = {'term_id': b:terminal_job_id, 'send': function("s:SendToTerm")}
    call extend(g:send_target, g:send_multiline[term_type])
endfunction

function! s:SendOpts(ArgLead, CmdLine, CursorPos)
    return keys(g:send_multiline)
endfunction

function! s:SendToTerm(lines)
    " destination is a term
    let dest = g:send_target
    if len(a:lines) > 1
        let line = dest.begin . join(a:lines, dest.newline) . dest.end
    else
        let line = a:lines[0] . "\n"
    endif
    call jobsend(dest.term_id, line)
    " If sending over multiple commands ([count]ss), slow down a little to
    " let some REPLs catch up (IPython, basically)
    if v:count1 > 1
        sleep 100m
    endif
endfunction

command! -complete=customlist,<SID>SendOpts -nargs=? SendHere :call <SID>SendHere(<f-args>)

" General 'Send' framework
function! s:Send(mode, ...)
    if !exists('g:send_target')
        echoerr 'Target terminal not set. Do :SendHere in the desired terminal.'
        return 0
    endif

    if a:mode ==# 'direct'
        " explicit lines provided as function arguments
        let lines = copy(a:000)
    else
        " mode tells how the operator s was used. e.g.
        " viws  v     (char-wise visual)
        " Vjjs  V     (line-vise visual)
        " siw   char  (char-wise normal text-object)
        " sG    line  (line-wise normal text-object)
        " In first two cases, marks are < and >. In the last two, marks are [ ]
        let marks = (a:mode ==? 'v')? ["'<", "'>"]: ["'[", "']"]
        let lines = getline(marks[0], marks[1])
        if a:mode ==# 'char' || a:mode ==# 'v'
            " For char-based modes, truncate first and last lines
            let col0 = col(marks[0]) - 1
            let col1 = col(marks[1]) - 1
            if len(lines) == 1
                let lines[0] = lines[0][col0:col1]
            else
                let lines[0] = lines[0][col0:]
                let lines[-1] = lines[-1][:col1]
            endif
        end
    endif

    call g:send_target.send(lines)
endfunction

nmap <silent> ss :call <SID>Send('direct', getline('.'))<cr>
nmap <silent> S s$

nmap <silent> s :set opfunc=<SID>Send<cr>g@
vmap <silent> s :<c-u>call <SID>Send(visualmode())<cr>
