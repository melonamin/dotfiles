function devcon --description "Use dev containers with templates from a central location"
    # Check if we have enough arguments
    if test (count $argv) -lt 1
        echo "Usage: devcon [up|exec|list|create] [container-type] [command...]"
        echo "Examples:"
        echo "  devcon up claude       # Start a Claude container"
        echo "  devcon exec claude bash  # Execute bash in a Claude container"
        echo "  devcon list            # List available templates"
        echo "  devcon create rust     # Create a new Rust template"
        return 1
    end
    set command_type $argv[1]
    set templates_root "$HOME/.devcontainers"
    # Handle list command
    if test "$command_type" = "list"
        echo "Available container templates:"
        ls -1 "$templates_root"
        return 0
    end
    # Handle create command
    if test "$command_type" = "create"
        set template_name $argv[2]
        set template_path "$templates_root/$template_name"
        if test -d "$template_path"
            echo "Template '$template_name' already exists"
            return 1
        end
        mkdir -p "$template_path"
        echo "Created template directory: $template_path"
        echo "Don't forget to create devcontainer.json and Dockerfile files"
        return 0
    end
    # For up and exec commands, we need a container type
    set container_type $argv[2]
    set container_path "$templates_root/$container_type"
    set container_config "$templates_root/$container_type/devcontainer.json"
    # Check if container type exists
    if not test -d "$container_path"
        echo "Error: Container template '$container_type' not found in $templates_root"
        echo "Available templates:"
        ls -1 "$templates_root"
        return 1
    end

    # Check if .devcontainers folder exists in current directory
    if test -d ".devcontainers"
        set config_flag "--override-config"
    else
        set config_flag "--config"
    end

    # Handle up command
    if test "$command_type" = "up"
        devcontainer up $config_flag "$container_config" --workspace-folder (pwd)
        # If additional arguments are provided, execute them
        if test (count $argv) -gt 2
            set -e argv[1] # Remove 'up'
            set -e argv[1] # Remove container type
            devcontainer exec $config_flag "$container_config" --workspace-folder (pwd) $argv
            # Stop container after exec completes
            devcontainer down $config_flag "$container_config" --workspace-folder (pwd)
        end
    # Handle exec command
    else if test "$command_type" = "exec"
        # Remove the first two arguments (exec and container-type)
        set -e argv[1]
        set -e argv[1]

        # Get container ID to check if it's running
        set container_id (devcontainer info $config_flag "$container_config" --workspace-folder (pwd) | grep -o 'Container ID: [a-zA-Z0-9]*' | awk '{print $3}')
        set container_running false

        if test -n "$container_id"
            # Check if container is running
            if docker ps -q --filter "id=$container_id" | grep -q .
                set container_running true
            end
        end

        # If container is not running, start it first
        if test "$container_running" = "false"
            echo "Container is not running. Starting it first..."
            devcontainer up $config_flag "$container_config" --workspace-folder (pwd)
        end

        # If no additional arguments, default to bash
        if test (count $argv) -eq 0
            devcontainer exec $config_flag "$container_config" --workspace-folder (pwd) bash
        else
            devcontainer exec $config_flag "$container_config" --workspace-folder (pwd) $argv
        end

        # Stop container after exec completes
        echo "Stopping container after exec session..."
        devcontainer down $config_flag "$container_config" --workspace-folder (pwd)
    else
        echo "Unknown command: $command_type"
        echo "Available commands: up, exec, list, create"
        return 1
    end
end
# Shorthand functions for common operations
function dcup --description "Start a container with a specific template"
    devcon up $argv
end
function dcexec --description "Execute a command in a container with a specific template"
    devcon exec $argv
end
function dclaude --description "Work with Claude container"
    if test (count $argv) -eq 0
        devcon up claude claude
    else if test "$argv[1]" = "up"
        set -e argv[1]
        devcon up claude $argv
    else if test "$argv[1]" = "exec"
        set -e argv[1]
        devcon exec claude $argv
    else
        devcon exec claude $argv
    end
end
