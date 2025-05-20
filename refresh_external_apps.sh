#!/bin/bash

# set info
SOURCE_DIR=""
TARGET_DIR="$HOME/Applications"

# if info empty
EMPTY_COUNT=0
if [ -z "$SOURCE_DIR" ]; then
    ((EMPTY_COUNT++))
fi
if [ -z "$TARGET_DIR" ]; then
    ((EMPTY_COUNT++))
fi
if [ $EMPTY_COUNT -gt 0 ]; then
    echo "Err: please fill in the source and target dir at the line 4 and 5 of me"
    echo "=== done ==="
    exit 1
fi


if [ ! -d "$SOURCE_DIR" ]; then
    echo "Err: source dir $SOURCE_DIR not exists"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "creating target dir $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

linked_count=0
skipped_count=0
removed_count=0

echo "=== sync softlink ==="
while IFS= read -r app_path; do
    app_name=$(basename "$app_path")
    target_path="$TARGET_DIR/$app_name"
    
    # check if exists already
    if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$app_path" ]; then
        echo "skip $app_name (already exists)"
        ((skipped_count++))
    elif [ -e "$target_path" ]; then
        echo "skip $app_name (it's there already but not a link)"
        ((skipped_count++))
    else
        # link
        ln -s "$app_path" "$target_path"
        if [ $? -eq 0 ]; then
            echo "linked $app_name"
            ((linked_count++))
        else
            echo "failed creating $app_name 's link"
        fi
    fi
done < <(find "$SOURCE_DIR" -maxdepth 1 -name "*.app" -type d)

echo -e "\n=== clean up dead softlink ==="
while IFS= read -r symlink_path; do
    # fwtch softlink target
    target=$(readlink "$symlink_path")
    app_name=$(basename "$symlink_path")
    
    if [ ! -e "$target" ]; then
        echo "added invalid softlink: $app_name -> $target (non-existent)"
        rm "$symlink_path"
        if [ $? -eq 0 ]; then
            ((removed_count++))
        else
            echo "failed deleting $symlink_path"
        fi
    fi
done < <(find "$TARGET_DIR" -maxdepth 1 -name "*.app" -type l)

echo -e "\n=== result ==="
echo "- created $linked_count softlink(s)"
echo "- skipped $skipped_count app(s)"
echo "- deleted $removed_count dead softlink(s)"
echo "=== done ==="