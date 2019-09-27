import os
from flask import request, jsonify
import psycopg2
from app_generator import create_app

app = create_app()

database_url = os.getenv('DATABASE_URL')

QUERY = """
set timezone TO 'Europe/Prague';
WITH stops_nearby AS (
    SELECT stops.stop_id
    FROM gtfs.stops
    ORDER BY gtfs.stops.the_geom <-> ST_GeomFromText(%(location)s, 4326)
    LIMIT 10
)
SELECT r.route_short_name, trip_headsign, departure_time, s.stop_name
FROM gtfs.stops s
left join gtfs.stop_times st on s.stop_id = st.stop_id
left join gtfs.trips t on t.trip_id = st.trip_id
left join gtfs.calendar c on c.service_id = t.service_id
left join gtfs.routes r on r.route_id = t.route_id
WHERE departure_time::time > current_time and departure_time::time < current_time + interval '15 minutes'
and c.start_date <= current_date
and c.end_date >= current_date
and s.stop_id in (select * from stops_nearby)
and (
CASE
    WHEN extract(dow from current_date) = 1 THEN c.monday::boolean = true
    WHEN extract(dow from current_date) = 2 THEN c.tuesday::boolean = true
    WHEN extract(dow from current_date) = 3 THEN c.wednesday::boolean = true
    WHEN extract(dow from current_date) = 4 THEN c.thursday::boolean = true
    WHEN extract(dow from current_date) = 5 THEN c.friday::boolean = true
    WHEN extract(dow from current_date) = 6 THEN c.saturday::boolean = true
    WHEN extract(dow from current_date) = 0 THEN c.sunday::boolean = true
END
)
order by departure_time;
"""

def convert(item):
    return (item[0], item[1], str(item[2]), item[3])

@app.route("/api/departures", methods=["GET"])
def api():
    latitude = request.args.get('latitude')
    longitude = request.args.get('longitude')

    connection = psycopg2.connect(database_url)
    cursor = connection.cursor()
    try:
        cursor.execute(QUERY, {"location": f"POINT({longitude} {latitude})"})
        data = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()
    data = [convert(item) for item in data]
    return jsonify(data)
