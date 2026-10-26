import 'leaflet/dist/leaflet.css';
import { CircleMarker, MapContainer, Polyline, TileLayer, Tooltip, useMap } from 'react-leaflet';
import { useEffect } from 'react';

export interface MapMarker {
  id: string;
  lat: number;
  lng: number;
  color: string;
  label?: string;
  radius?: number;
  onClick?: () => void;
}
export interface MapLine {
  id: string;
  points: [number, number][];
  color: string;
}

export const MEKNES: [number, number] = [33.8935, -5.5473];

function Recenter({ center, follow }: { center: [number, number]; follow?: boolean }) {
  const map = useMap();
  useEffect(() => {
    if (follow) map.setView(center);
  }, [center, follow, map]);
  return null;
}

/** Leaflet + OpenStreetMap (D18). Circle markers avoid image assets (CSP-friendly). */
export default function MapView({ center = MEKNES, zoom = 13, markers = [], lines = [], height = 420, follow }: { center?: [number, number]; zoom?: number; markers?: MapMarker[]; lines?: MapLine[]; height?: number; follow?: boolean }) {
  return (
    <div className="map" style={{ height }}>
      <MapContainer center={center} zoom={zoom} style={{ height: '100%', width: '100%' }}>
        <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" subdomains={['a', 'b', 'c']} />
        <Recenter center={center} follow={follow} />
        {lines.map((l) => (
          <Polyline key={l.id} positions={l.points} pathOptions={{ color: l.color, weight: 4 }} />
        ))}
        {markers.map((m) => (
          <CircleMarker
            key={m.id}
            center={[m.lat, m.lng]}
            radius={m.radius ?? 7}
            pathOptions={{ color: '#fff', weight: 2, fillColor: m.color, fillOpacity: 0.95 }}
            eventHandlers={m.onClick ? { click: m.onClick } : undefined}
          >
            {m.label && <Tooltip>{m.label}</Tooltip>}
          </CircleMarker>
        ))}
      </MapContainer>
    </div>
  );
}
