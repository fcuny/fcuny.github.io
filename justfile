# Run the local HTTP server
run:
	zola serve

# Generate the content of the site under ./docs
build:
	zola build

# Format files
fmt:
	treefmt

# Check that all the links are valid
check-links: build
	lychee ./docs/**/*.html

# Update flake dependencies
update-deps:
	nix flake update --commit-lock-file

# Publish the site to https://fcuny.net
publish: fmt verify-gps-removal build check-links
	rsync -a docs/ fcuny@fcuny.net:/srv/www/fcuny.net

# Remove GPS data from JPG, JPEG, and PNG files in the static directory
remove-gps-data:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Removing GPS data from images in the static directory..."
    find ./static -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | \
    while IFS= read -r -d '' file; do
        echo "Processing: $file"
        if exiftool -GPS*= "$file"; then
            if [ -f "${file}_original" ]; then
                echo "GPS data removed from $file"
                rm "${file}_original"
            else
                echo "No GPS data found in $file"
            fi
        else
            echo "Error processing $file"
        fi
    done
    echo "GPS data removal process complete."

# Verify if GPS data has been removed from images in the static directory
verify-gps-removal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Verifying GPS data removal in the static directory..."
    found_gps=0
    while IFS= read -r -d '' file; do
        if exiftool "$file" | grep -q "GPS"; then
            echo "WARNING: GPS data found in $file"
            found_gps=1
        else
            echo "OK: No GPS data in $file"
        fi
    done < <(find ./static -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0)
    echo "Verification complete."
    if [ $found_gps -eq 1 ]; then
        echo "ERROR: GPS data found in one or more images in the static directory."
        exit 1
    else
        echo "SUCCESS: No GPS data found in any images in the static directory."
    fi
