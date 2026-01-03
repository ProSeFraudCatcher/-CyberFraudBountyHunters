# include this from .bashrc, .zshrc or
# another shell startup file with:
#   source $HOME/.shellfishrc

# this script does nothing outside ShellFish
if [[ "$LC_TERMINAL" = "ShellFish" ]]; then
  ios_printURIComponent() {
    awk 'BEGIN {while (y++ < 125) z[sprintf("%c", y)] = y
    while (y = substr(ARGV[1], ++j, 1))
    q = y ~ /[a-zA-Z0-9]/ ? q y : q sprintf("%%%02X", z[y])
    printf("%s", q)}' "$1"
  }

  ios_printOSC() {
    if [[ -n "$TMUX" ]]; then
      awk 'BEGIN {printf "\033Ptmux;\033\033]"}'
    else
      awk 'BEGIN {printf "\033]"}'
    fi
  }

  ios_printST() {
    if [[ -n "$TMUX" ]]; then
      awk 'BEGIN {printf "\a\033\\"}'
    else
      awk 'BEGIN {printf "\a"}'
    fi
  }
  
  ios_urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }
  
  # wait for terminal to complete action
  ios_handleResult() {
    read -s
    
    local error=${REPLY#error=}
    if [[ $REPLY = error* ]]; then
      >&2 ios_urldecode "${REPLY#error=}"
      return 1
    fi
    
    if [[ $REPLY = result* ]]; then
      ios_urldecode "${REPLY#result=}"
    fi
  }

  # sharesheet should be called with
  # filenames as arguments that will open
  # in system sharesheet. Alternatively you
  # can pipe in text and call it without
  # arguments
  sharesheet() {
    ios_printOSC
    awk 'BEGIN {printf "6;sharesheet://?pwd="}'
    ios_printURIComponent "$PWD"
    awk 'BEGIN {printf "&home="}'
    ios_printURIComponent "$HOME"
    for var in "$@"
    do
      awk 'BEGIN {printf "&path="}'
      ios_printURIComponent "$var"
    done
    if [[ $# -eq 0 ]]; then
      text=$(cat -)
      awk 'BEGIN {printf "&text="}'
      ios_printURIComponent "$text"
    fi
    ios_printST
    ios_handleResult
  }
  
  # quicklook is called with filenames as
  # arguments. Alternatively you can pipe
  # in text and call it without arguments
  quicklook() {
    ios_printOSC
    awk 'BEGIN {printf "6;quicklook://?pwd="}'
    ios_printURIComponent "$PWD"
    awk 'BEGIN {printf "&home="}'
    ios_printURIComponent "$HOME"
    for var in "$@"
    do
      awk 'BEGIN {printf "&path="}'
      ios_printURIComponent "$var"
    done
    if [[ $# -eq 0 ]]; then
      text=$(cat -)
      awk 'BEGIN {printf "&text="}'
      ios_printURIComponent "$text"
    fi
    ios_printST
    ios_handleResult
  }

  textastic() {
    if [[ $# -eq 0 ]]; then
      cat <<EOF
Usage: textastic <text-file>

Open in Textastic 9.5 or later.
File must be in directory represented in the Files app to allow writing back edits.
EOF
    else
      ios_printOSC
      awk 'BEGIN {printf "6;textastic://?pwd="}'
      ios_printURIComponent "$PWD"
      awk 'BEGIN {printf "&home="}'
      ios_printURIComponent "$HOME"
      awk 'BEGIN {printf "&path="}'
      ios_printURIComponent "$1"
      ios_printST
    fi
  }
  
  openUrl() {
    if [[ $# -eq 0 ]]; then
      cat <<EOF
Usage: openUrl <url>

Open URL on iOS.
EOF
    else
      ios_printOSC
      awk 'BEGIN {printf "6;open://?url="}'
      ios_printURIComponent "$1"
      ios_printST
      ios_handleResult
    fi
  }

  runShortcut() {
    if [[ $# -eq 0 ]]; then
      cat <<EOF
Usage: runShortcut <shortcut-name> [input-for-shortcut]

Run in Shortcuts app.
EOF
    else
      local name=$(printURIComponent "$1")
      shift
      local input=$(printURIComponent "$*")
      openUrl "shortcuts://run-shortcut?name=$name&input=$input"
    fi
  }

  notify() {
    if [[ $# -eq 0 ]]; then
      cat <<EOF
Usage: notify <title> [body]

Show notification on iOS device.
Title cannot contain semicolon.
EOF
    else
      local title="${1-}" body="${2-}"
      ios_printOSC
      echo $title | awk -F";" 'BEGIN {printf "777;notify;"} {printf "%s;", $1}'
      echo $body
      ios_printST
    fi
  }

  # copy standard input or arguments to iOS clipboard
  pbcopy() {
    ios_printOSC
    awk 'BEGIN {printf "52;c;"} '
    if [ $# -eq 0 ]; then
      base64 | tr -d '\n'
    else
      echo -n "$@" | base64 | tr -d '\n'
    fi
    ios_printST
  }

  # Secure ShellFish supports 24-bit colors
  export COLORTERM=truecolor
  
  # tmux mouse mode enables scrolling with
  # two-finger swipe and mouse wheel
  if [[ -n "$TMUX" ]]; then
      tmux set -g mouse on
  fi

  # send the current directory using OSC 7 when showing prompt to
  # make filename detection work better for interactive shell
  if [[ -z "$INSIDE_EMACS" && $- = *i* ]]; then
    update_terminal_cwd() {
      ios_printOSC
      awk "BEGIN {printf \"7;%s\", \"file://$HOSTNAME\"}"
      ios_printURIComponent "$PWD"
      ios_printST
    }
    if [ -n "$ZSH_VERSION" ]; then
      precmd() { update_terminal_cwd; }
    elif [[ $PROMPT_COMMAND != *"update_terminal_cwd"* ]]; then
      PROMPT_COMMAND="update_terminal_cwd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
  fi
fi
