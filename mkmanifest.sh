#!/bin/sh

# In English: ignore .git directories, then select files that aren't *.sh and
# print them without the leading "start point" (of "./"). Yes, this condition
# includes .manifest itself, this is intended.
find . -name ".git" -prune -o \! -name "*.sh" -type f -fprintf .manifest "%P\n"
