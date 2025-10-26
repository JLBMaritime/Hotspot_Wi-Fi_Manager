"""
Flask routes for WiFi Manager web interface and API
"""
from flask import render_template, jsonify, request
from app import app, auth
from app.wifi_manager import (
    scan_networks, get_current_connection, get_connection_ip,
    connect_to_network, forget_network, rescan_networks
)
from app.network_diagnostics import ping_test, get_full_diagnostics
from app.database import get_saved_networks, init_db

# Initialize database on startup
init_db()

@app.route('/')
@auth.login_required
def index():
    """Serve the main web interface"""
    return render_template('index.html')

@app.route('/api/scan', methods=['GET'])
@auth.login_required
def api_scan():
    """API endpoint to scan for available networks"""
    networks = scan_networks()
    return jsonify({'success': True, 'networks': networks})

@app.route('/api/rescan', methods=['POST'])
@auth.login_required
def api_rescan():
    """API endpoint to trigger a new scan"""
    networks = rescan_networks()
    return jsonify({'success': True, 'networks': networks})

@app.route('/api/current', methods=['GET'])
@auth.login_required
def api_current():
    """API endpoint to get current connection"""
    current = get_current_connection()
    ip = get_connection_ip()
    return jsonify({
        'success': True,
        'current': current,
        'ip': ip
    })

@app.route('/api/saved', methods=['GET'])
@auth.login_required
def api_saved():
    """API endpoint to get saved networks"""
    saved = get_saved_networks()
    return jsonify({'success': True, 'networks': saved})

@app.route('/api/connect', methods=['POST'])
@auth.login_required
def api_connect():
    """API endpoint to connect to a network"""
    data = request.json
    ssid = data.get('ssid')
    password = data.get('password')
    
    if not ssid:
        return jsonify({'success': False, 'message': 'SSID is required'}), 400
    
    success, message = connect_to_network(ssid, password)
    return jsonify({'success': success, 'message': message})

@app.route('/api/forget', methods=['POST'])
@auth.login_required
def api_forget():
    """API endpoint to forget a network"""
    data = request.json
    ssid = data.get('ssid')
    
    if not ssid:
        return jsonify({'success': False, 'message': 'SSID is required'}), 400
    
    success, message = forget_network(ssid)
    return jsonify({'success': success, 'message': message})

@app.route('/api/ping', methods=['POST'])
@auth.login_required
def api_ping():
    """API endpoint to run a ping test"""
    data = request.json
    host = data.get('host', '8.8.8.8')
    count = data.get('count', 4)
    
    result = ping_test(host, count)
    return jsonify(result)

@app.route('/api/diagnostics', methods=['GET'])
@auth.login_required
def api_diagnostics():
    """API endpoint to get network diagnostics"""
    diagnostics = get_full_diagnostics()
    return jsonify({'success': True, 'diagnostics': diagnostics})

@app.route('/api/status', methods=['GET'])
@auth.login_required
def api_status():
    """API endpoint to get complete system status"""
    current = get_current_connection()
    ip = get_connection_ip()
    saved = get_saved_networks()
    
    return jsonify({
        'success': True,
        'current': current,
        'ip': ip,
        'saved_count': len(saved)
    })
