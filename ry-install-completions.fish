# Fish completions for ry-install v4.0.1
# Install: cp ry-install-completions.fish ~/.config/fish/completions/ry-install.fish
#
# Completions defined for both 'ry-install' (if renamed/installed) and 'ry-install.fish' (direct invocation)

# Define completions for both command names
for cmd in ry-install ry-install.fish
    complete -c $cmd -f

    # Installation
    complete -c $cmd -l all -d 'Unattended installation (auto-yes)'
    complete -c $cmd -l force -d 'Auto-yes all prompts (for --clean, --all, etc.)'
    complete -c $cmd -l verbose -d 'Show output on terminal'
    complete -c $cmd -l dry-run -d 'Preview changes without modifying system'

    # Verification
    complete -c $cmd -l diff -d 'Compare embedded files against system'
    complete -c $cmd -l verify -d 'Run full verification (static + runtime)'
    complete -c $cmd -l verify-static -d 'Verify config file existence and content'
    complete -c $cmd -l verify-runtime -d 'Verify live system state (after reboot)'
    complete -c $cmd -l lint -d 'Run fish syntax and anti-pattern checks'

    # Utilities
    complete -c $cmd -l status -d 'Quick system health dashboard'
    complete -c $cmd -l watch -d 'Live monitoring mode'
    complete -c $cmd -l clean -d 'System cleanup (cache, journal, orphans)'
    complete -c $cmd -l wifi-diag -d 'WiFi diagnostics and troubleshooting'
    complete -c $cmd -l benchmark -d 'Quick performance sanity check'
    complete -c $cmd -l export -d 'Export system config for sharing'
    complete -c $cmd -l backup-list -d 'List available configuration backups'
    complete -c $cmd -l logs -d 'View logs (system, gpu, wifi, boot, audio, usb, or service name)'
    complete -c $cmd -l diagnose -d 'Automated problem detection'

    # Other
    complete -c $cmd -l no-color -d 'Disable colored output'
    complete -c $cmd -s h -l help -d 'Show help'
    complete -c $cmd -s v -l version -d 'Show version'

    # Completions for --logs subcommands
    complete -c $cmd -l logs -xa 'system gpu wifi boot audio usb'
end
