#!/usr/bin/env python3
"""
WiFi Manager CLI
Command-line interface version for SSH access
"""
import sys
import os

# Add parent directory to path to import app modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.wifi_manager import (
    scan_networks, get_current_connection, get_connection_ip,
    connect_to_network, forget_network as wifi_forget_network, rescan_networks
)
from app.network_diagnostics import ping_test, get_full_diagnostics
from app.database import get_saved_networks, init_db

def print_header():
    """Print CLI header"""
    print("\n" + "="*60)
    print("JLBMaritime WiFi Manager CLI")
    print("="*60)

def print_menu():
    """Print main menu"""
    print("\nMain Menu:")
    print("1. Scan for networks")
    print("2. Connect to network")
    print("3. Show current connection")
    print("4. List saved networks")
    print("5. Forget network")
    print("6. Run network diagnostics")
    print("7. Run ping test")
    print("8. Exit")
    print("-"*60)

def scan_and_display():
    """Scan and display available networks"""
    print("\nScanning for networks...")
    networks = scan_networks()
    
    if not networks:
        print("No networks found.")
        return
    
    print(f"\nFound {len(networks)} networks:")
    print("-"*60)
    print(f"{'#':<4} {'SSID':<30} {'Signal':<10} {'Security':<10}")
    print("-"*60)
    
    for idx, network in enumerate(networks, 1):
        ssid = network['ssid'][:28]  # Truncate long SSIDs
        signal = f"{network['signal']}%"
        security = network['security']
        print(f"{idx:<4} {ssid:<30} {signal:<10} {security:<10}")
    
    print("-"*60)

def connect_to_network_cli():
    """Connect to a network via CLI"""
    print("\n--- Connect to Network ---")
    
    # First scan networks
    scan_and_display()
    
    ssid = input("\nEnter network SSID (or 'c' to cancel): ").strip()
    if ssid.lower() == 'c':
        return
    
    if not ssid:
        print("Error: SSID cannot be empty")
        return
    
    password = input("Enter password (leave empty for open networks): ").strip()
    
    print(f"\nConnecting to '{ssid}'...")
    success, message = connect_to_network(ssid, password if password else None)
    
    if success:
        print(f"✓ {message}")
    else:
        print(f"✗ {message}")

def show_current_connection():
    """Display current connection information"""
    print("\n--- Current Connection ---")
    
    current = get_current_connection()
    ip = get_connection_ip()
    
    if current and current['ssid']:
        print(f"Network:    {current['ssid']}")
        print(f"IP Address: {ip}")
    else:
        print("Not connected to any network")

def list_saved_networks_cli():
    """List saved networks"""
    print("\n--- Saved Networks ---")
    
    saved = get_saved_networks()
    current = get_current_connection()
    current_ssid = current['ssid'] if current else None
    
    if not saved:
        print("No saved networks")
        return
    
    print("-"*60)
    print(f"{'#':<4} {'SSID':<40} {'Status':<10}")
    print("-"*60)
    
    for idx, network in enumerate(saved, 1):
        ssid = network['ssid'][:38]
        status = "(Connected)" if network['ssid'] == current_ssid else ""
        print(f"{idx:<4} {ssid:<40} {status:<10}")
    
    print("-"*60)

def forget_network_cli():
    """Forget a saved network"""
    print("\n--- Forget Network ---")
    
    # List saved networks first
    saved = get_saved_networks()
    current = get_current_connection()
    current_ssid = current['ssid'] if current else None
    
    if not saved:
        print("No saved networks")
        return
    
    print("-"*60)
    print(f"{'#':<4} {'SSID':<40} {'Status':<10}")
    print("-"*60)
    
    for idx, network in enumerate(saved, 1):
        ssid = network['ssid'][:38]
        status = "(Connected)" if network['ssid'] == current_ssid else ""
        print(f"{idx:<4} {ssid:<40} {status:<10}")
    
    print("-"*60)
    
    choice = input("\nEnter network number to forget (or 'c' to cancel): ").strip()
    
    if choice.lower() == 'c':
        return
    
    try:
        idx = int(choice)
        if 1 <= idx <= len(saved):
            ssid = saved[idx - 1]['ssid']
            
            # Confirm
            confirm = input(f"Forget '{ssid}'? (y/n): ").strip().lower()
            if confirm != 'y':
                print("Cancelled")
                return
            
            success, message = wifi_forget_network(ssid)
            if success:
                print(f"✓ {message}")
            else:
                print(f"✗ {message}")
        else:
            print("Invalid network number")
    except ValueError:
        print("Invalid input")

def run_diagnostics():
    """Run and display network diagnostics"""
    print("\n--- Network Diagnostics ---")
    
    diagnostics = get_full_diagnostics()
    
    # Interface status
    print("\nInterface Status:")
    for iface, info in diagnostics['interfaces'].items():
        print(f"  {iface}: {info['status']}")
    
    # Connection stats
    if diagnostics['connection_stats']:
        print("\nConnection Statistics:")
        for key, value in diagnostics['connection_stats'].items():
            print(f"  {key}: {value}")
    
    # Gateway and DNS
    print(f"\nGateway: {diagnostics['gateway']}")
    print(f"DNS Servers: {', '.join(diagnostics['dns_servers'])}")

def run_ping_test_cli():
    """Run ping test via CLI"""
    print("\n--- Ping Test ---")
    
    host = input("Enter host to ping (default: 8.8.8.8): ").strip()
    if not host:
        host = "8.8.8.8"
    
    count = input("Enter number of pings (default: 4): ").strip()
    try:
        count = int(count) if count else 4
    except ValueError:
        count = 4
    
    print(f"\nPinging {host}...")
    result = ping_test(host, count)
    
    if result['success']:
        print(f"\n✓ Ping successful")
        if 'packet_loss' in result:
            print(f"Packet Loss: {result['packet_loss']}")
        if 'min_time' in result:
            print(f"Min: {result['min_time']}")
            print(f"Avg: {result['avg_time']}")
            print(f"Max: {result['max_time']}")
        print(f"\nFull output:\n{result['output']}")
    else:
        print(f"\n✗ Ping failed")
        print(f"Error: {result['output']}")

def main():
    """Main CLI loop"""
    # Initialize database
    init_db()
    
    # Check if running as root
    if os.geteuid() != 0:
        print("Warning: This tool should be run with sudo for full functionality")
        print("Example: sudo python3 cli/wifi_cli.py")
        response = input("\nContinue anyway? (y/n): ").strip().lower()
        if response != 'y':
            sys.exit(0)
    
    print_header()
    
    while True:
        print_menu()
        choice = input("Enter your choice (1-8): ").strip()
        
        try:
            if choice == '1':
                scan_and_display()
            elif choice == '2':
                connect_to_network_cli()
            elif choice == '3':
                show_current_connection()
            elif choice == '4':
                list_saved_networks_cli()
            elif choice == '5':
                forget_network_cli()
            elif choice == '6':
                run_diagnostics()
            elif choice == '7':
                run_ping_test_cli()
            elif choice == '8':
                print("\nExiting WiFi Manager CLI...")
                sys.exit(0)
            else:
                print("\nInvalid choice. Please enter a number between 1 and 8.")
        except KeyboardInterrupt:
            print("\n\nExiting WiFi Manager CLI...")
            sys.exit(0)
        except Exception as e:
            print(f"\nError: {e}")
        
        input("\nPress Enter to continue...")

if __name__ == '__main__':
    main()
