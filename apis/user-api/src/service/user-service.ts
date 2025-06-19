import { type sendUnaryData, type ServerUnaryCall, status } from '@grpc/grpc-js'
import {
  GetUserRequest,
  GetUserResponse,
  ListUsersRequest,
  ListUsersResponse,
  CreateUserRequest,
  CreateUserResponse,
  UpdateUserRequest,
  UpdateUserResponse,
  DeleteUserRequest,
  DeleteUserResponse,
  User as UserProto,
} from '../generated/user.js'
import { UserRepository, type User } from '../data/users.js'

function userToProto(user: User): UserProto {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  }
}

export const userServiceImplementation = {
  getUser: (
    call: ServerUnaryCall<GetUserRequest, GetUserResponse>,
    callback: sendUnaryData<GetUserResponse>,
  ) => {
    const id = call.request.id

    if (!id) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'User ID is required',
      })
    }

    const user = UserRepository.getById(id)
    if (!user) {
      return callback({
        code: status.NOT_FOUND,
        details: `User with ID ${id} not found`,
      })
    }

    const response: GetUserResponse = {
      user: userToProto(user),
    }
    callback(null, response)
  },

  listUsers: (
    call: ServerUnaryCall<ListUsersRequest, ListUsersResponse>,
    callback: sendUnaryData<ListUsersResponse>,
  ) => {
    const pageSize = call.request.pageSize || 10
    const pageToken = call.request.pageToken || ''
    const filter = call.request.filter || ''

    let users: User[]
    if (filter) {
      users = UserRepository.getAll(filter)
      const response: ListUsersResponse = {
        users: users.map(userToProto),
        totalCount: users.length,
        nextPageToken: '',
      }
      return callback(null, response)
    }

    const result = UserRepository.paginate(pageSize, pageToken)
    const response: ListUsersResponse = {
      users: result.users.map(userToProto),
      totalCount: result.totalCount,
      nextPageToken: result.nextPageToken,
    }

    callback(null, response)
  },

  createUser: (
    call: ServerUnaryCall<CreateUserRequest, CreateUserResponse>,
    callback: sendUnaryData<CreateUserResponse>,
  ) => {
    const email = call.request.email
    const name = call.request.name
    const role = call.request.role

    if (!email || !name || !role) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'Email, name, and role are required',
      })
    }

    const user = UserRepository.create({ email, name, role })
    const response: CreateUserResponse = {
      user: userToProto(user),
    }

    callback(null, response)
  },

  updateUser: (
    call: ServerUnaryCall<UpdateUserRequest, UpdateUserResponse>,
    callback: sendUnaryData<UpdateUserResponse>,
  ) => {
    const id = call.request.id
    const email = call.request.email
    const name = call.request.name
    const role = call.request.role

    if (!id) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'User ID is required',
      })
    }

    const updateData: Partial<Omit<User, 'id' | 'createdAt'>> = {}
    if (email) updateData.email = email
    if (name) updateData.name = name
    if (role) updateData.role = role

    const user = UserRepository.update(id, updateData)
    if (!user) {
      return callback({
        code: status.NOT_FOUND,
        details: `User with ID ${id} not found`,
      })
    }

    const response: UpdateUserResponse = {
      user: userToProto(user),
    }

    callback(null, response)
  },

  deleteUser: (
    call: ServerUnaryCall<DeleteUserRequest, DeleteUserResponse>,
    callback: sendUnaryData<DeleteUserResponse>,
  ) => {
    const id = call.request.id

    if (!id) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'User ID is required',
      })
    }

    const success = UserRepository.delete(id)
    if (!success) {
      return callback({
        code: status.NOT_FOUND,
        details: `User with ID ${id} not found`,
      })
    }

    const response: DeleteUserResponse = {
      success: true,
    }

    callback(null, response)
  },
}
