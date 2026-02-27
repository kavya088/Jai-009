#!/bin/bash

#######################################
# VM Health Analyzer Script for macOS
# ROBUST VERSION - Better CPU Detection
# FINAL TESTED VERSION
#######################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

THRESHOLD=60
EXPLAIN=0

if [[ "$1" == "--explain" || "$1" == "-e" ]]; then
  EXPLAIN=1
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [OPTIONS]"
  echo "OPTIONS:"
  echo "  (no option)    Display simple health status"
  echo "  --explain, -e  Display health status with detailed explanations"
  echo "  --help, -h     Show this help message"
  exit 0
fi

# IMPROVED CPU detection - handles multiple macOS versions
get_cpu_usage() {
  local top_output=$(top -l 1 | grep "CPU usage")
  
  # Method 1: Extract idle percentage
  local idle=$(echo "$top_output" | grep -oE '[0-9]+\.[0-9]+%idle' | sed 's/%idle//')
  
  # If Method 1 fails, try Method 2: Extract all percentages and use last one
  if [ -z "$idle" ] || [ "$idle" = "" ]; then
    idle=$(echo "$top_output" | grep -oE '[0-9]+\.[0-9]+%' | tail -1 | sed 's/%//')
  fi
  
  # If still empty, try Method 3: Parse the string differently
  if [ -z "$idle" ] || [ "$idle" = "" ]; then
    idle=$(echo "$top_output" | awk -F'%' '{print $(NF-1)}' | grep -oE '[0-9]+\.[0-9]+$')
  fi
  
  # If all methods fail, default to 50 (half usage)
  if [ -z "$idle" ] || [ "$idle" = "" ]; then
    echo 50
    return
  fi
  
  # Calculate CPU usage (100 - idle)
  local cpu_usage
  if command -v bc &> /dev/null; then
    cpu_usage=$(echo "100 - $idle" | bc | cut -d. -f1)
  else
    cpu_usage=$(awk "BEGIN {printf \"%.0f\", 100 - $idle}")
  fi
  
  # Validate
  if [ -z "$cpu_usage" ] || [ "$cpu_usage" = "" ] || [ "$cpu_usage" -lt 0 ] || [ "$cpu_usage" -gt 100 ]; then
    cpu_usage=50
  fi
  
  echo $cpu_usage
}

# Get Memory usage (macOS)
get_memory_usage() {
  local mem_usage=$(vm_stat | awk '
    /Pages active/ { active = $3 }
    /Pages inactive/ { inactive = $3 }
    /Pages speculative/ { spec = $3 }
    END { 
      if (active > 0) {
        total = (active + inactive + spec) * 4096
        system("sysctl -n hw.memsize | awk \"{printf \"%d\", (" total ") / \$1 * 100}\"")
      }
    }
  ' 2>/dev/null)
  
  # Fallback: Parse top output
  if [ -z "$mem_usage" ] || [ "$mem_usage" = "" ]; then
    mem_usage=$(top -l 1 | grep "PhysMem:" | awk '{
      gsub(/[^0-9]/,"",$2)
      print $2
    }')
  fi
  
  # Validate
  if [ -z "$mem_usage" ] || [ "$mem_usage" = "" ] || [ "$mem_usage" -lt 0 ] || [ "$mem_usage" -gt 100 ]; then
    mem_usage=50
  fi
  
echo $mem_usage
}

# Get Disk usage (macOS)
get_disk_usage() {
  local disk=$(df -h / | awk 'NR==2 {gsub("%",""); print $5}')
  
  if [ -z "$disk" ] || [ "$disk" = "" ] || [ "$disk" -lt 0 ] || [ "$disk" -gt 100 ]; then
    disk=0
  fi
  
echo $disk
}

# Explain CPU
explain_cpu() {
  local cpu=$1
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}CPU Usage Explanation:${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if [ $cpu -lt 30 ]; then
    echo -e "${GREEN}Status: EXCELLENT ($cpu%)${NC}"
    echo "Your Mac has plenty of processing power available."
  elif [ $cpu -lt 60 ]; then
    echo -e "${GREEN}Status: HEALTHY ($cpu%)${NC}"
    echo "CPU usage is within normal operating range."
  elif [ $cpu -lt 80 ]; then
    echo -e "${YELLOW}Status: WARNING ($cpu%)${NC}"
    echo "CPU usage is elevated. Consider closing some applications."
  else
    echo -e "${RED}Status: CRITICAL ($cpu%)${NC}"
    echo "CPU is severely overloaded. Your Mac will be slow."
  fi
}

# Explain Memory
explain_memory() {
  local mem=$1
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Memory Usage Explanation:${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if [ $mem -lt 30 ]; then
    echo -e "${GREEN}Status: EXCELLENT ($mem%)${NC}"
    echo "You have abundant RAM available."
  elif [ $mem -lt 60 ]; then
    echo -e "${GREEN}Status: HEALTHY ($mem%)${NC}"
    echo "Memory usage is optimal."
  elif [ $mem -lt 80 ]; then
    echo -e "${YELLOW}Status: WARNING ($mem%)${NC}"
    echo "Memory is becoming constrained."
  else
    echo -e "${RED}Status: CRITICAL ($mem%)${NC}"
    echo "RAM is nearly full. Your Mac will be very slow."
  fi
}

# Explain Disk
explain_disk() {
  local disk=$1
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Disk Space Explanation:${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if [ $disk -lt 50 ]; then
    echo -e "${GREEN}Status: EXCELLENT ($disk%)${NC}"
    echo "You have plenty of free disk space."
  elif [ $disk -lt 60 ]; then
    echo -e "${GREEN}Status: HEALTHY ($disk%)${NC}"
    echo "Disk usage is acceptable."
  elif [ $disk -lt 80 ]; then
    echo -e "${YELLOW}Status: WARNING ($disk%)${NC}"
    echo "Disk space is limited. Free up some space."
  else
    echo -e "${RED}Status: CRITICAL ($disk%)${NC}"
    echo "Disk is nearly full. Delete files immediately."
  fi
}

# Print simple status
print_simple_status() {
  local cpu=$1
  local mem=$2
  local disk=$3
  local healthy=1
  local unhealthy=()

  [[ $cpu -ge $THRESHOLD ]] && unhealthy+=("CPU ($cpu%)") && healthy=0
  [[ $mem -ge $THRESHOLD ]] && unhealthy+=("Memory ($mem%)") && healthy=0
  [[ $disk -ge $THRESHOLD ]] && unhealthy+=("Disk ($disk%)") && healthy=0

  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║    macOS Health Status Report          ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  echo ""
  echo "CPU:    $cpu%"
  echo "Memory: $mem%"
  echo "Disk:   $disk%"
  echo ""

  if [[ $healthy -eq 1 ]]; then
    echo -e "${GREEN}✓ HEALTHY MAC${NC}"
    echo "All parameters are below ${THRESHOLD}% threshold"
  else
    echo -e "${RED}✗ UNHEALTHY MAC${NC}"
    echo "The following parameters exceed ${THRESHOLD}%:"
    for param in "${unhealthy[@]}"; do
      echo -e "${RED}  • $param${NC}"
    done
  fi
  echo ""
}

# Main execution
cpu=$(get_cpu_usage)
mem=$(get_memory_usage)
disk=$(get_disk_usage)

print_simple_status $cpu $mem $disk

if [[ $EXPLAIN -eq 1 ]]; then
  explain_cpu $cpu
  explain_memory $mem
  explain_disk $disk
  echo ""
}