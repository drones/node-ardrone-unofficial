
{Drone} = require './drone'
{timeoutSet, intervalSet} = require './util'


drone = new Drone
drone.awaken()

timeoutSet 2000, () =>
  drone.takeoff()

  timeoutSet 3000, () =>
    drone.land()


