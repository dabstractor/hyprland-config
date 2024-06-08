HARD_LIMIT=200

if [ -z "$1" ]; then
    echo "Usage: $0 <increment>"
    exit 1
fi

# Increment volume by the specified percentage
INCREMENT=$1

# Get the current volume
CURRENT_VOLUME=$(pamixer --get-volume)

# Calculate the new volume
NEW_VOLUME=$((CURRENT_VOLUME + INCREMENT))

# Check if the new volume exceeds the hard limit
if [ "$NEW_VOLUME" -gt "$HARD_LIMIT" ]; then
    NEW_VOLUME=$HARD_LIMIT
fi

# Set the new volume
pamixer --allow-boost --set-volume $NEW_VOLUME
