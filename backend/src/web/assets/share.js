// Trip share page: polls the public share endpoint and moves the car marker. No cookies, no tracking.
(function () {
  var token = document.body.getAttribute('data-token');
  var map = L.map('map', { zoomControl: true }).setView([33.8935, -5.5473], 13);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '© OpenStreetMap' }).addTo(map);
  var car = null, pickup = null, dropoff = null, fitted = false;
  var statusText = JSON.parse(document.getElementById('i18n').textContent);
  function tick() {
    fetch('/v1/share/' + encodeURIComponent(token)).then(function (r) {
      if (!r.ok) throw new Error('gone');
      return r.json();
    }).then(function (d) {
      document.getElementById('status').textContent = statusText[d.status] || d.status;
      document.getElementById('driver').textContent = d.driver ? d.driver.first_name + (d.driver.rating ? ' ★' + d.driver.rating : '') : '—';
      document.getElementById('car').textContent = d.vehicle ? [d.vehicle.make, d.vehicle.model, d.vehicle.colour].join(' ') : '—';
      document.getElementById('plate').textContent = d.vehicle ? d.vehicle.plate : '—';
      if (!pickup) pickup = L.circleMarker([d.pickup.lat, d.pickup.lng], { radius: 7, color: '#0B6E4F' }).addTo(map);
      if (!dropoff) dropoff = L.circleMarker([d.dropoff.lat, d.dropoff.lng], { radius: 7, color: '#F4A300' }).addTo(map);
      if (d.position) {
        var ll = [d.position.lat, d.position.lng];
        if (!car) car = L.marker(ll).addTo(map); else car.setLatLng(ll);
        document.getElementById('updated').textContent = new Date(d.position.at).toLocaleTimeString();
      }
      if (!fitted) { map.fitBounds(L.latLngBounds([[d.pickup.lat, d.pickup.lng], [d.dropoff.lat, d.dropoff.lng]]).pad(0.3)); fitted = true; }
      if (d.status === 'completed' || d.status === 'cancelled') return;
      setTimeout(tick, 5000);
    }).catch(function () {
      document.getElementById('status').textContent = statusText.expired_link;
    });
  }
  tick();
})();
