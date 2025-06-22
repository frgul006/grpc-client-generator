import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { UserRepository, type User, type UserFilter } from '../../data/users.js'

describe('UserRepository', () => {
  let originalUsers: Map<string, User>

  beforeEach(() => {
    // Store reference to original users for restoration
    originalUsers = new Map(UserRepository.users)

    // Clear repository before each test
    UserRepository.users.clear()

    // Add test users
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
      {
        id: '3',
        email: 'test3@example.com',
        name: 'Test User 3',
        role: 'user',
        createdAt: Date.now() - 21600000,
        updatedAt: Date.now() - 21600000,
      },
    ]

    testUsers.forEach((user) => UserRepository.users.set(user.id, user))
  })

  afterEach(() => {
    // Restore original users
    UserRepository.users.clear()
    originalUsers.forEach((user, id) => UserRepository.users.set(id, user))
  })

  describe('getById', () => {
    it('should return user when found', () => {
      const user = UserRepository.getById('1')

      expect(user).toBeDefined()
      expect(user?.id).toBe('1')
      expect(user?.email).toBe('test1@example.com')
      expect(user?.name).toBe('Test User 1')
      expect(user?.role).toBe('user')
    })

    it('should return undefined when user not found', () => {
      const user = UserRepository.getById('999')
      expect(user).toBeUndefined()
    })

    it('should return undefined for empty string id', () => {
      const user = UserRepository.getById('')
      expect(user).toBeUndefined()
    })
  })

  describe('getAll', () => {
    it('should return all users when no filter provided', () => {
      const users = UserRepository.getAll()

      expect(users).toHaveLength(3)
      expect(users.map((u) => u.id)).toEqual(['1', '2', '3'])
    })

    it('should return empty array when no users exist', () => {
      UserRepository.users.clear()
      const users = UserRepository.getAll()

      expect(users).toHaveLength(0)
      expect(users).toEqual([])
    })

    it('should filter users by name (case insensitive)', () => {
      const users = UserRepository.getAll({ searchTerm: 'test user 1' })

      expect(users).toHaveLength(1)
      expect(users[0]?.id).toBe('1')
    })

    it('should filter users by email (case insensitive)', () => {
      const users = UserRepository.getAll({ searchTerm: 'TEST2@EXAMPLE.COM' })

      expect(users).toHaveLength(1)
      expect(users[0]?.id).toBe('2')
    })

    it('should filter users by role (case insensitive)', () => {
      const users = UserRepository.getAll({ searchTerm: 'ADMIN' })

      expect(users).toHaveLength(1)
      expect(users[0]?.id).toBe('2')
      expect(users[0]?.role).toBe('admin')
    })

    it('should return multiple matching users', () => {
      const users = UserRepository.getAll({ searchTerm: 'user' }) // matches role 'user' and names containing 'User'

      expect(users).toHaveLength(3) // All test users have 'User' in name or role
      expect(users.map((u) => u.id)).toEqual(['1', '2', '3'])
    })

    it('should return empty array when filter matches nothing', () => {
      const users = UserRepository.getAll({ searchTerm: 'nonexistent' })

      expect(users).toHaveLength(0)
    })

    it('should handle partial matches in all fields', () => {
      const users = UserRepository.getAll({ searchTerm: 'test' }) // matches all names

      expect(users).toHaveLength(3)
    })
  })

  describe('create', () => {
    it('should create new user with generated id and timestamps', () => {
      const userData = {
        email: 'new@example.com',
        name: 'New User',
        role: 'user',
      }

      const user = UserRepository.create(userData)

      expect(user.id).toBeDefined()
      expect(user.id).toBe('4') // Next sequential ID
      expect(user.email).toBe('new@example.com')
      expect(user.name).toBe('New User')
      expect(user.role).toBe('user')
      expect(user.createdAt).toBeDefined()
      expect(user.updatedAt).toBeDefined()
      expect(user.createdAt).toBe(user.updatedAt)
    })

    it('should store created user in repository', () => {
      const userData = {
        email: 'stored@example.com',
        name: 'Stored User',
        role: 'admin',
      }

      const user = UserRepository.create(userData)
      const retrieved = UserRepository.getById(user.id)

      expect(retrieved).toEqual(user)
    })

    it('should generate sequential IDs', () => {
      const user1 = UserRepository.create({
        email: 'user1@example.com',
        name: 'User 1',
        role: 'user',
      })

      const user2 = UserRepository.create({
        email: 'user2@example.com',
        name: 'User 2',
        role: 'user',
      })

      expect(parseInt(user1.id)).toBeLessThan(parseInt(user2.id))
      expect(parseInt(user2.id) - parseInt(user1.id)).toBe(1)
    })

    it('should set timestamps correctly', () => {
      const beforeCreate = Date.now()
      const user = UserRepository.create({
        email: 'timestamp@example.com',
        name: 'Timestamp User',
        role: 'user',
      })
      const afterCreate = Date.now()

      expect(user.createdAt).toBeGreaterThanOrEqual(beforeCreate)
      expect(user.createdAt).toBeLessThanOrEqual(afterCreate)
      expect(user.updatedAt).toBe(user.createdAt)
    })
  })

  describe('update', () => {
    it('should update existing user and return updated user', () => {
      const updateData = {
        email: 'updated@example.com',
        name: 'Updated User',
        role: 'admin',
      }

      const user = UserRepository.update('1', updateData)

      expect(user).toBeDefined()
      expect(user?.id).toBe('1')
      expect(user?.email).toBe('updated@example.com')
      expect(user?.name).toBe('Updated User')
      expect(user?.role).toBe('admin')
      expect(user?.updatedAt).toBeGreaterThan(user!.createdAt)
    })

    it('should preserve original createdAt timestamp', () => {
      const original = UserRepository.getById('1')
      const originalCreatedAt = original!.createdAt

      const user = UserRepository.update('1', { name: 'Updated Name' })

      expect(user?.createdAt).toBe(originalCreatedAt)
    })

    it('should update only provided fields', () => {
      const original = UserRepository.getById('1')

      const user = UserRepository.update('1', { name: 'New Name Only' })

      expect(user?.name).toBe('New Name Only')
      expect(user?.email).toBe(original?.email)
      expect(user?.role).toBe(original?.role)
    })

    it('should return null when user not found', () => {
      const user = UserRepository.update('999', { name: 'No User' })
      expect(user).toBeNull()
    })

    it('should update updatedAt timestamp', () => {
      const original = UserRepository.getById('1')
      const originalUpdatedAt = original!.updatedAt

      // Small delay to ensure timestamp difference
      setTimeout(() => {
        const user = UserRepository.update('1', { name: 'Updated' })
        expect(user?.updatedAt).toBeGreaterThan(originalUpdatedAt)
      }, 1)
    })

    it('should handle empty update data', () => {
      const original = UserRepository.getById('1')
      const user = UserRepository.update('1', {})

      expect(user?.email).toBe(original?.email)
      expect(user?.name).toBe(original?.name)
      expect(user?.role).toBe(original?.role)
      expect(user?.updatedAt).toBeGreaterThan(original!.updatedAt)
    })

    it('should not allow updating id or createdAt', () => {
      const original = UserRepository.getById('1')
      const updateData = {
        email: 'new@example.com',
        // These should not be updatable
        id: '999',
        createdAt: Date.now() + 1000000,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
      } as any

      const user = UserRepository.update('1', updateData)

      expect(user?.id).toBe('1') // Should remain unchanged
      expect(user?.createdAt).toBe(original?.createdAt) // Should remain unchanged
      expect(user?.email).toBe('new@example.com') // Should be updated
    })
  })

  describe('delete', () => {
    it('should delete existing user and return true', () => {
      const result = UserRepository.delete('1')

      expect(result).toBe(true)
      expect(UserRepository.getById('1')).toBeUndefined()
    })

    it('should return false when user not found', () => {
      const result = UserRepository.delete('999')
      expect(result).toBe(false)
    })

    it('should not affect other users when deleting', () => {
      UserRepository.delete('2')

      expect(UserRepository.getById('1')).toBeDefined()
      expect(UserRepository.getById('3')).toBeDefined()
      expect(UserRepository.getById('2')).toBeUndefined()
    })

    it('should reduce total user count', () => {
      const beforeCount = UserRepository.getAll().length
      UserRepository.delete('1')
      const afterCount = UserRepository.getAll().length

      expect(afterCount).toBe(beforeCount - 1)
    })
  })

  describe('paginate', () => {
    it('should return first page with specified page size', () => {
      const result = UserRepository.paginate(2, '')

      expect(result.users).toHaveLength(2)
      expect(result.totalCount).toBe(3)
      expect(result.nextPageToken).toBe('2')
      expect(result.users.map((u) => u.id)).toEqual(['1', '2'])
    })

    it('should return second page when page token provided', () => {
      const result = UserRepository.paginate(2, '2')

      expect(result.users).toHaveLength(1)
      expect(result.totalCount).toBe(3)
      expect(result.nextPageToken).toBe('')
      expect(result.users[0]?.id).toBe('3')
    })

    it('should return empty next page token when no more pages', () => {
      const result = UserRepository.paginate(5, '')

      expect(result.users).toHaveLength(3)
      expect(result.nextPageToken).toBe('')
      expect(result.totalCount).toBe(3)
    })

    it('should handle page size larger than total users', () => {
      const result = UserRepository.paginate(10, '')

      expect(result.users).toHaveLength(3)
      expect(result.nextPageToken).toBe('')
      expect(result.totalCount).toBe(3)
    })

    it('should handle invalid page token gracefully', () => {
      const result = UserRepository.paginate(2, 'invalid')

      expect(result.users).toHaveLength(2)
      expect(result.totalCount).toBe(3)
    })

    it('should handle zero page size', () => {
      const result = UserRepository.paginate(0, '')

      expect(result.users).toHaveLength(0)
      expect(result.nextPageToken).toBe('0')
      expect(result.totalCount).toBe(3)
    })

    it('should handle page token beyond available data', () => {
      const result = UserRepository.paginate(2, '10')

      expect(result.users).toHaveLength(0)
      expect(result.nextPageToken).toBe('')
      expect(result.totalCount).toBe(3)
    })

    it('should return users in consistent order', () => {
      const page1 = UserRepository.paginate(1, '')
      const page2 = UserRepository.paginate(1, '1')
      const page3 = UserRepository.paginate(1, '2')

      expect(page1.users[0]?.id).toBe('1')
      expect(page2.users[0]?.id).toBe('2')
      expect(page3.users[0]?.id).toBe('3')
    })
  })

  describe('integration scenarios', () => {
    it('should handle full CRUD cycle', () => {
      // Create
      const newUser = UserRepository.create({
        email: 'crud@example.com',
        name: 'CRUD User',
        role: 'user',
      })
      expect(newUser.id).toBeDefined()

      // Read
      const retrieved = UserRepository.getById(newUser.id)
      expect(retrieved).toEqual(newUser)

      // Update
      const updated = UserRepository.update(newUser.id, {
        name: 'Updated CRUD User',
        role: 'admin',
      })
      expect(updated?.name).toBe('Updated CRUD User')
      expect(updated?.role).toBe('admin')

      // Delete
      const deleted = UserRepository.delete(newUser.id)
      expect(deleted).toBe(true)
      expect(UserRepository.getById(newUser.id)).toBeUndefined()
    })

    it('should maintain data consistency across operations', () => {
      const initialCount = UserRepository.getAll().length

      // Create user
      const newUser = UserRepository.create({
        email: 'consistency@example.com',
        name: 'Consistency User',
        role: 'user',
      })

      expect(UserRepository.getAll().length).toBe(initialCount + 1)

      // Update user
      UserRepository.update(newUser.id, { name: 'Updated' })
      expect(UserRepository.getAll().length).toBe(initialCount + 1)

      // Delete user
      UserRepository.delete(newUser.id)
      expect(UserRepository.getAll().length).toBe(initialCount)
    })
  })
})
