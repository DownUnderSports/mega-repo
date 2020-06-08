import { RouteParser } from 'react-component-templates/helpers';
import Routes from 'routes/routes.json'

const RouteList =  new RouteParser(Routes.links || {}, 1)

export default RouteList
