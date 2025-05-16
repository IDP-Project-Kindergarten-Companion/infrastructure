#!/bin/bash

# Array of port forwarding commands
# now only the mongo-express and kong services are exposed, the rest are exposed with kong
commands=(
  # "kubectl port-forward svc/activity-log-svc -n kindergarten-app 8084:5003"
  # "kubectl port-forward svc/db-interact-svc -n kindergarten-app 8082:5000"
  # "kubectl port-forward svc/child-profile-svc -n kindergarten-app 8083:5002"
  # "kubectl port-forward svc/auth-svc -n kindergarten-app 8081:5051"
  "kubectl port-forward svc/mongo-express-auth-svc -n kindergarten-app 8501:8081"
  "kubectl port-forward svc/mongo-express-op-svc -n kindergarten-app 8502:8081"
  "kubectl port-forward svc/portainer -n portainer 9443:9443"
  "kubectl port-forward svc/kong-kong-admin -n kong 8001:8001"
  "kubectl port-forward svc/kong-kong-proxy -n kong 8000:80"
)

# Array to store process IDs (PIDs)
declare -a pids=() # Explicitly declare pids as an array

# Function to execute a command in the background and store its PID
execute_command() {
  # Execute the command in the background (&)
  # Capture the PID of the background process ($!)
  eval "$1" &
  local pid=$! # Store the PID in a local variable
  pids+=("$pid")       # Append the PID to the array
  echo "Started: $1 with PID $pid"
}

# Function to terminate all background processes
terminate_processes() {
  if [ ${#pids[@]} -gt 0 ]; then
    echo "Terminating the following processes:"
    for pid in "${pids[@]}"; do
      echo "  PID: $pid"
      # Use kill command to terminate the process
      kill "$pid"
    done
    # Clear the pids array
    pids=()
  else
    echo "No processes to terminate."
  fi
}

# Trap SIGINT (Ctrl+C) and SIGTERM signals to run terminate_processes function
trap terminate_processes SIGINT SIGTERM

# Loop through the commands and execute them in the background
for command in "${commands[@]}"; do
  execute_command "$command"
done

# Wait indefinitely to keep the script running and the port forwardings active
# Use a loop that sleeps for a long time, and checks if the pids are still running
while true; do
  sleep 600 # Sleep for 10 minutes (adjust as needed)
  all_pids_alive=true
  if [ ${#pids[@]} -gt 0 ]; then
    for pid in "${pids[@]}"; do
      # Check if the process is running using 'kill -0' (does not send a signal)
      if ! kill -0 "$pid"; then
        echo "Process with PID $pid is no longer running."
        all_pids_alive=false
        break # Exit the loop, no need to check other pids
      fi
    done
  else
    all_pids_alive=false # Exit the loop
  fi

  if ! $all_pids_alive; then
    echo "Some or all processes have stopped. Exiting."
    break
  fi
done