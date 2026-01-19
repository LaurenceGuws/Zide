#!/usr/bin/env bash
set -euo pipefail

# Manual terminal protocol checks for Zide.
# Run inside the Zide integrated terminal.

printf %s "Starting XTGETTCAP test. Use 'cat -v' to see replies.\n"

# XTGETTCAP: TN, Co, RGB.
printf %s $'\033P+q544E\033\\'
printf %s $'\033P+q436F\033\\'
printf %s $'\033P+q524742\033\\'

printf %s "XTGETTCAP queries sent (TN/Co/RGB).\n"
