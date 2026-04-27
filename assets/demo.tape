# nanobrain — VHS demo script
# Render: vhs assets/demo.tape -o assets/demo.gif

Output assets/demo.gif

Set Shell "bash"
Set FontSize 16
Set FontFamily "JetBrains Mono"
Set Width 1100
Set Height 720
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0
Set Padding 20

Hide
Type "cd $HOME/Documents/nanobrain"
Enter
Type "export BRAIN_DIR=$PWD/examples/starter-brain"
Enter
Type "clear"
Enter
Sleep 500ms
Show

# Title
Type "# nanobrain — your second brain in markdown"
Sleep 500ms
Enter
Sleep 800ms

# 1. Brain health overview
Type "bin/nanobrain status"
Enter
Sleep 2500ms

# 2. Search across the corpus
Type "bin/nanobrain who jane"
Enter
Sleep 3000ms

# 3. Enumerate projects
Type "bin/nanobrain list project"
Enter
Sleep 2000ms

# 4. Read one entity
Type "bin/nanobrain show person jane-doe"
Enter
Sleep 4500ms

# Closing
Hide
Type "clear"
Enter
Show
Type "# Markdown + git. Vendor-neutral."
Enter
Type "# Anthropic Memory locks you in. nanobrain travels with you."
Enter
Sleep 2500ms
