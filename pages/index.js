import { usePosition } from 'use-position';
import { useAsync } from 'react-async-hook';
import Head from 'next/head'

const groupBy = function (xs, key) {
  return xs.reduce(function (rv, x) {
    (rv[x[key]] = rv[x[key]] || []).push(x);
    return rv;
  }, {});
};

function HomePage() {
  const { latitude, longitude, error } = usePosition();
  const departures = useAsync(async () => {
    if (!latitude || !longitude) {
      return []
    }
    const response = await fetch(
      `/api/departures?latitude=${latitude}&longitude=${longitude}`
    )
    return await response.json()
  }, [latitude, longitude]);

  return (
    <>
      <Head>
        <title>Departures</title>
      </Head>
      <p>{error}</p>
      <h2>Departures</h2>
      {departures.loading && <div>...</div>}
      {departures.error && <div>Error: {departures.error.message}</div>}
      {departures.result
        ? Object.entries(groupBy(departures.result, 3)).map(([key,group]) => (
          <div key={key}>
            <h4>{key}</h4>
            {group.filter(([route_short_name, trip_headsign, departure_time, stop_name])=> trip_headsign !== stop_name).map(([route_short_name, trip_headsign, departure_time, stop_name]) =>(
            <p key={route_short_name + stop_name + departure_time}>
              <em>{route_short_name} - {trip_headsign}</em> {departure_time}
          </p>
          ))}
          </div>
          ))
        : null}
    </>
  )
}

export default HomePage
