export interface User {
  id: string
  email: string
  name: string
  role: string
  createdAt: number
  updatedAt: number
}

export interface UserFilter {
  searchTerm?: string
}

// In-memory user storage
const users = new Map<string, User>()

// Sample data
const sampleUsers: User[] = [
  {
    id: '1',
    email: 'john.doe@example.com',
    name: 'John Doe',
    role: 'admin',
    createdAt: Date.now() - 86400000,
    updatedAt: Date.now() - 86400000,
  },
  {
    id: '2',
    email: 'jane.smith@example.com',
    name: 'Jane Smith',
    role: 'user',
    createdAt: Date.now() - 43200000,
    updatedAt: Date.now() - 43200000,
  },
  {
    id: '3',
    email: 'bob.wilson@example.com',
    name: 'Bob Wilson',
    role: 'user',
    createdAt: Date.now() - 21600000,
    updatedAt: Date.now() - 21600000,
  },
]

// Initialize with sample data
sampleUsers.forEach((user) => users.set(user.id, user))

export class UserRepository {
  // Expose users map for testing purposes
  static get users(): Map<string, User> {
    return users
  }

  static getById(id: string): User | undefined {
    return users.get(id)
  }

  static getAll(filter?: UserFilter): User[] {
    const allUsers = Array.from(users.values())
    if (!filter?.searchTerm) return allUsers

    const filterLower = filter.searchTerm.toLowerCase()
    return allUsers.filter(
      (user) =>
        user.name.toLowerCase().includes(filterLower) ||
        user.email.toLowerCase().includes(filterLower) ||
        user.role.toLowerCase().includes(filterLower),
    )
  }

  static create(userData: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): User {
    const id = (users.size + 1).toString()
    const now = Date.now()
    const user: User = {
      id,
      ...userData,
      createdAt: now,
      updatedAt: now,
    }
    users.set(id, user)
    return user
  }

  static update(id: string, userData: Partial<User>): User | null {
    const existing = users.get(id)
    if (!existing) return null

    // Filter out id and createdAt from update data to prevent overwriting
    const {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      id: _id,
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      createdAt: _createdAt,
      ...safeUpdateData
    } = userData

    const updated: User = {
      ...existing,
      ...safeUpdateData,
      updatedAt: Date.now(),
    }
    users.set(id, updated)
    return updated
  }

  static delete(id: string): boolean {
    return users.delete(id)
  }

  static paginate(
    pageSize: number,
    pageToken: string,
    filter?: UserFilter,
  ): { users: User[]; nextPageToken: string; totalCount: number } {
    const allUsers = this.getAll(filter)
    let startIndex = 0

    if (pageToken) {
      const parsedToken = parseInt(pageToken)
      // Only use parsed token if it's a valid number, otherwise start from beginning
      if (!isNaN(parsedToken) && parsedToken >= 0) {
        startIndex = parsedToken
      }
    }

    const endIndex = startIndex + pageSize
    const paginatedUsers = allUsers.slice(startIndex, endIndex)
    const nextPageToken = endIndex < allUsers.length ? endIndex.toString() : ''

    return {
      users: paginatedUsers,
      nextPageToken,
      totalCount: allUsers.length,
    }
  }
}
