/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { status } from '@grpc/grpc-js'
import { userServiceImplementation } from '../../service/user-service.js'
import { UserRepository, type User } from '../../data/users.js'
import { mockConsole, restoreConsole } from '../setup.js'

describe('UserService', () => {
  let originalUsers: Map<string, User>

  beforeEach(() => {
    // Store original data
    originalUsers = new Map(UserRepository.users)

    // Clear and setup test data
    UserRepository.users.clear()

    const testUsers: User[] = [
      {
        id: '1',
        email: 'test1@example.com',
        name: 'Test User 1',
        role: 'user',
        createdAt: Date.now() - 86400000,
        updatedAt: Date.now() - 86400000,
      },
      {
        id: '2',
        email: 'test2@example.com',
        name: 'Test User 2',
        role: 'admin',
        createdAt: Date.now() - 43200000,
        updatedAt: Date.now() - 43200000,
      },
    ]

    testUsers.forEach((user) => UserRepository.users.set(user.id, user))

    mockConsole()
  })

  afterEach(() => {
    // Restore original data
    UserRepository.users.clear()
    originalUsers.forEach((user, id) => UserRepository.users.set(id, user))

    restoreConsole()
  })

  describe('getUser', () => {
    it('should return user when found', () => {
      const mockRequest = {
        id: '1',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.getUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(
        null,
        expect.objectContaining({
          user: expect.objectContaining({
            id: '1',
            email: 'test1@example.com',
            name: 'Test User 1',
          }),
        }),
      )
    })

    it('should return NOT_FOUND error when user does not exist', () => {
      const mockRequest = {
        id: '999',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.getUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.NOT_FOUND,
        details: 'User with ID 999 not found',
      })
    })

    it('should return INVALID_ARGUMENT error when id is missing', () => {
      const mockRequest = {
        id: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.getUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'User ID is required',
      })
    })
  })

  describe('listUsers', () => {
    it('should return users with default pagination', () => {
      const mockRequest = {
        pageSize: 0, // Should default to 10
        pageToken: '',
        filter: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.listUsers(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(
        null,
        expect.objectContaining({
          users: expect.any(Array),
          nextPageToken: expect.any(String),
          totalCount: expect.any(Number),
        }),
      )
    })

    it('should handle pagination parameters', () => {
      const mockRequest = {
        pageSize: 1,
        pageToken: '',
        filter: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.listUsers(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(
        null,
        expect.objectContaining({
          users: expect.any(Array),
          nextPageToken: expect.any(String),
          totalCount: expect.any(Number),
        }),
      )
    })

    it('should handle filter parameter', () => {
      const mockRequest = {
        pageSize: 10,
        pageToken: '',
        filter: 'admin',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.listUsers(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(
        null,
        expect.objectContaining({
          users: expect.any(Array),
          nextPageToken: expect.any(String),
          totalCount: expect.any(Number),
        }),
      )
    })
  })

  describe('createUser', () => {
    it('should create user with valid data', () => {
      const mockRequest = {
        email: 'new@example.com',
        name: 'New User',
        role: 'user',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.createUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(
        null,
        expect.objectContaining({
          user: expect.objectContaining({
            email: 'new@example.com',
            name: 'New User',
            role: 'user',
          }),
        }),
      )
    })

    it('should return INVALID_ARGUMENT error when email is missing', () => {
      const mockRequest = {
        email: '',
        name: 'New User',
        role: 'user',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.createUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Email, name, and role are required',
      })
    })

    it('should return INVALID_ARGUMENT error when name is missing', () => {
      const mockRequest = {
        email: 'new@example.com',
        name: '',
        role: 'user',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.createUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Email, name, and role are required',
      })
    })

    it('should return INVALID_ARGUMENT error when role is missing', () => {
      const mockRequest = {
        email: 'new@example.com',
        name: 'New User',
        role: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.createUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Email, name, and role are required',
      })
    })
  })

  describe('updateUser', () => {
    it('should update existing user', () => {
      const mockRequest = {
        id: '1',
        email: 'updated@example.com',
        name: 'Updated User',
        role: 'admin',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.updateUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object))
      expect(mockCallback).not.toHaveBeenCalledWith(
        expect.objectContaining({ code: expect.any(Number) }),
      )
    })

    it('should return INVALID_ARGUMENT error when id is missing', () => {
      const mockRequest = {
        id: '',
        email: 'updated@example.com',
        name: 'Updated User',
        role: 'admin',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.updateUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'User ID is required',
      })
    })

    it('should return NOT_FOUND error when user does not exist', () => {
      const mockRequest = {
        id: '999',
        email: 'updated@example.com',
        name: 'Updated User',
        role: 'admin',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.updateUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.NOT_FOUND,
        details: 'User with ID 999 not found',
      })
    })

    it('should handle partial updates', () => {
      const mockRequest = {
        id: '1',
        email: 'updated@example.com',
        name: '',
        role: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.updateUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object))
    })
  })

  describe('deleteUser', () => {
    it('should delete existing user', () => {
      const mockRequest = {
        id: '1',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.deleteUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object))
      expect(mockCallback).not.toHaveBeenCalledWith(
        expect.objectContaining({ code: expect.any(Number) }),
      )
    })

    it('should return INVALID_ARGUMENT error when id is missing', () => {
      const mockRequest = {
        id: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.deleteUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'User ID is required',
      })
    })

    it('should return NOT_FOUND error when user does not exist', () => {
      const mockRequest = {
        id: '999',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.deleteUser(mockCall as any, mockCallback)

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.NOT_FOUND,
        details: 'User with ID 999 not found',
      })
    })
  })

  describe('error handling', () => {
    it('should handle repository errors gracefully', () => {
      // Mock UserRepository to throw an error
      const originalGetById = UserRepository.getById
      UserRepository.getById = vi.fn().mockImplementation(() => {
        throw new Error('Database error')
      })

      const mockRequest = {
        id: '1',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      expect(() => {
        userServiceImplementation.getUser(mockCall as any, mockCallback)
      }).toThrow('Database error')

      // Restore original method
      UserRepository.getById = originalGetById
    })
  })

  describe('data transformation', () => {
    it('should properly transform user data for responses', () => {
      const mockRequest = {
        id: '1',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.getUser(mockCall as any, mockCallback)

      // Verify the response was called with proper data structure
      expect(mockCallback).toHaveBeenCalledWith(
        null,
        expect.objectContaining({
          user: expect.objectContaining({
            id: '1',
            email: 'test1@example.com',
            name: 'Test User 1',
          }),
        }),
      )
    })
  })

  describe('integration with UserRepository', () => {
    it('should call UserRepository methods with correct parameters', () => {
      const getByIdSpy = vi.spyOn(UserRepository, 'getById')

      const mockRequest = {
        id: '1',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.getUser(mockCall as any, mockCallback)

      expect(getByIdSpy).toHaveBeenCalledWith('1')

      getByIdSpy.mockRestore()
    })

    it('should call UserRepository create method with correct parameters', () => {
      const createSpy = vi.spyOn(UserRepository, 'create')

      const mockRequest = {
        email: 'new@example.com',
        name: 'New User',
        role: 'user',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.createUser(mockCall as any, mockCallback)

      expect(createSpy).toHaveBeenCalledWith({
        email: 'new@example.com',
        name: 'New User',
        role: 'user',
      })

      createSpy.mockRestore()
    })

    it('should call UserRepository update method with correct parameters', () => {
      const updateSpy = vi.spyOn(UserRepository, 'update')

      const mockRequest = {
        id: '1',
        email: 'updated@example.com',
        name: '',
        role: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.updateUser(mockCall as any, mockCallback)

      expect(updateSpy).toHaveBeenCalledWith('1', {
        email: 'updated@example.com',
      })

      updateSpy.mockRestore()
    })

    it('should call UserRepository delete method with correct parameters', () => {
      const deleteSpy = vi.spyOn(UserRepository, 'delete')

      const mockRequest = {
        id: '1',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.deleteUser(mockCall as any, mockCallback)

      expect(deleteSpy).toHaveBeenCalledWith('1')

      deleteSpy.mockRestore()
    })

    it('should call UserRepository paginate method with correct parameters', () => {
      const paginateSpy = vi.spyOn(UserRepository, 'paginate')

      const mockRequest = {
        pageSize: 5,
        pageToken: 'token123',
        filter: '',
      }
      const mockCall = { request: mockRequest }
      const mockCallback = vi.fn()

      userServiceImplementation.listUsers(mockCall as any, mockCallback)

      expect(paginateSpy).toHaveBeenCalledWith(5, 'token123')

      paginateSpy.mockRestore()
    })
  })
})
