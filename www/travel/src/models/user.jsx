import BaseModel from 'models/base'

class UserModel extends BaseModel {
  modelName = 'users'
  storeName = 'users'
}

export default new UserModel()
