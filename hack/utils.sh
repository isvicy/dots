#!/bin/bash

asksure() {
  while read -r -n 1 -s answer; do
    if [[ $answer = [YyNn] ]]; then
      [[ $answer = [Yy] ]] && retval=0
      [[ $answer = [Nn] ]] && retval=1
      break
    fi
  done

  echo # just a final linefeed, optics...

  return "$retval"
}

ensureTargetDir() {
  dir=${1}
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}"
  fi
}
