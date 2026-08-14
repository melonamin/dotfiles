#!/bin/bash
# Disable phantom monitor duplicates.
# Some displays (e.g. Apple Studio Display over Thunderbolt) register two ports
# with the same serial. The phantom port has fewer available modes than the real one.
# This script groups monitors by serial and disables duplicates with fewer modes.

hyprctl monitors -j | jq -r '
  group_by(.serial)
  | .[]
  | select(length > 1)
  | sort_by(.availableModes | length)
  | .[:-1]
  | .[].name
' | while read -r monitor; do
    hyprctl keyword monitor "$monitor,disable"
done
