# Ensure SSH sockets directory exists for connection multiplexing
if not test -d ~/.ssh/sockets
    mkdir -p ~/.ssh/sockets
    chmod 700 ~/.ssh/sockets
end
