#!/usr/bin/env bash

error() {
    printf '\033[1;31m%s\033[0m\n' "$*" >&2
}
