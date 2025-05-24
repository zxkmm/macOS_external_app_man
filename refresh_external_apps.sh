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
created_dirs=0

# Function to recursively sync directories and create symlinks
sync_recursive() {
    local source_path="$1"
    local target_path="$2"
    local relative_path="$3"
    
    # Create target directory if it doesn't exist
    if [ ! -d "$target_path" ]; then
        mkdir -p "$target_path"
        if [ $? -eq 0 ]; then
            echo "created dir: $relative_path"
            ((created_dirs++))
        else
            echo "failed creating dir: $relative_path"
            return 1
        fi
    fi
    
    # Process all items in source directory
    while IFS= read -r item_path; do
        if [ -z "$item_path" ]; then
            continue
        fi
        
        item_name=$(basename "$item_path")
        target_item_path="$target_path/$item_name"
        relative_item_path="$relative_path/$item_name"
        
        if [ -d "$item_path" ] && [[ "$item_name" != *.app ]]; then
            # It's a directory (but not an .app bundle), recurse into it
            sync_recursive "$item_path" "$target_item_path" "$relative_item_path"
        else
            # It's a file or .app bundle, create symlink
            if [ -L "$target_item_path" ]; then
                # Target is a symlink, check if it points to the correct source
                current_target=$(readlink "$target_item_path")
                
                if [ "$current_target" = "$item_path" ]; then
                    echo "skip $relative_item_path (already exists)"
                    ((skipped_count++))
                else
                    # Symlink exists but points to wrong target, replace it
                    rm "$target_item_path"
                    ln -s "$item_path" "$target_item_path"
                    if [ $? -eq 0 ]; then
                        echo "updated symlink $relative_item_path"
                        ((linked_count++))
                    else
                        echo "failed updating link for $relative_item_path"
                    fi
                fi
            elif [ -e "$target_item_path" ]; then
                echo "skip $relative_item_path (exists but not a link)"
                ((skipped_count++))
            else
                ln -s "$item_path" "$target_item_path"
                if [ $? -eq 0 ]; then
                    echo "linked $relative_item_path"
                    ((linked_count++))
                else
                    echo "failed creating link for $relative_item_path"
                fi
            fi
        fi
    done < <(find "$source_path" -maxdepth 1 -mindepth 1 \( -type f -o -type d \) | sort)
}

# Function to recursively clean up dead symlinks
cleanup_recursive() {
    local target_path="$1"
    local relative_path="$2"
    
    # Find all symlinks in current directory
    while IFS= read -r symlink_path; do
        if [ -z "$symlink_path" ]; then
            continue
        fi
        
        symlink_name=$(basename "$symlink_path")
        relative_symlink_path="$relative_path/$symlink_name"
        
        # Follow the symlink chain to find the final target
        final_target=$(realpath "$symlink_path" 2>/dev/null)
        
        # Check if the final target exists
        if [ -z "$final_target" ] || [ ! -e "$final_target" ]; then
            # Get the immediate target for display purposes
            immediate_target=$(readlink "$symlink_path")
            echo "removed invalid symlink: $relative_symlink_path -> $immediate_target (broken chain)"
            rm "$symlink_path"
            if [ $? -eq 0 ]; then
                ((removed_count++))
            else
                echo "failed deleting $symlink_path"
            fi
        fi
    done < <(find "$target_path" -maxdepth 1 -type l)
    
    # Recurse into subdirectories
    while IFS= read -r dir_path; do
        if [ -z "$dir_path" ]; then
            continue
        fi
        
        dir_name=$(basename "$dir_path")
        relative_dir_path="$relative_path/$dir_name"
        cleanup_recursive "$dir_path" "$relative_dir_path"
        
        # Remove empty directories that were created by this script
        if [ -d "$dir_path" ] && [ -z "$(ls -A "$dir_path" 2>/dev/null)" ]; then
            # Check if this directory corresponds to a source directory
            source_equivalent="$SOURCE_DIR${dir_path#$TARGET_DIR}"
            if [ ! -d "$source_equivalent" ]; then
                echo "removed empty dir: $relative_dir_path"
                rmdir "$dir_path" 2>/dev/null
            fi
        fi
    done < <(find "$target_path" -maxdepth 1 -type d -mindepth 1)
}

echo "=== sync directories and softlinks ==="
sync_recursive "$SOURCE_DIR" "$TARGET_DIR" ""

echo -e "\n=== clean up dead softlinks ==="
cleanup_recursive "$TARGET_DIR" ""

echo -e "\n=== result ==="
echo "- created $created_dirs directory(ies)"
echo "- created $linked_count softlink(s)"
echo "- skipped $skipped_count item(s)"
echo "- deleted $removed_count dead softlink(s)"
echo "=== done ==="
