export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  sku: string;
  createdAt: number;
  updatedAt: number;
}

export interface Inventory {
  productId: string;
  quantity: number;
  warehouseId: string;
  lastRestocked: number;
}

// In-memory storage
const products = new Map<string, Product>();
const inventory = new Map<string, Inventory[]>();

// Sample data
const sampleProducts: Product[] = [
  {
    id: "1",
    name: 'MacBook Pro 16"',
    description: "Apple MacBook Pro with M3 chip, 16-inch display",
    price: 2499.99,
    category: "Electronics",
    sku: "MBP-16-M3-512",
    createdAt: Date.now() - 86400000,
    updatedAt: Date.now() - 86400000,
  },
  {
    id: "2",
    name: "iPhone 15 Pro",
    description: "Latest iPhone with A17 Pro chip and titanium design",
    price: 999.99,
    category: "Electronics",
    sku: "IPH-15-PRO-128",
    createdAt: Date.now() - 43200000,
    updatedAt: Date.now() - 43200000,
  },
  {
    id: "3",
    name: "AirPods Pro",
    description: "Wireless earbuds with active noise cancellation",
    price: 249.99,
    category: "Electronics",
    sku: "APP-GEN2-USB",
    createdAt: Date.now() - 21600000,
    updatedAt: Date.now() - 21600000,
  },
];

const sampleInventory: Inventory[] = [
  {
    productId: "1",
    quantity: 25,
    warehouseId: "warehouse-west",
    lastRestocked: Date.now() - 7200000,
  },
  {
    productId: "1",
    quantity: 30,
    warehouseId: "warehouse-east",
    lastRestocked: Date.now() - 3600000,
  },
  {
    productId: "2",
    quantity: 150,
    warehouseId: "warehouse-west",
    lastRestocked: Date.now() - 1800000,
  },
  {
    productId: "2",
    quantity: 120,
    warehouseId: "warehouse-east",
    lastRestocked: Date.now() - 900000,
  },
  {
    productId: "3",
    quantity: 80,
    warehouseId: "warehouse-west",
    lastRestocked: Date.now() - 14400000,
  },
  {
    productId: "3",
    quantity: 95,
    warehouseId: "warehouse-east",
    lastRestocked: Date.now() - 10800000,
  },
];

// Initialize with sample data
sampleProducts.forEach((product) => products.set(product.id, product));
sampleInventory.forEach((inv) => {
  const existing = inventory.get(inv.productId) || [];
  existing.push(inv);
  inventory.set(inv.productId, existing);
});

export class ProductRepository {
  // Expose products and inventory maps for testing purposes
  static get products(): Map<string, Product> {
    return products;
  }

  static get inventory(): Map<string, Inventory[]> {
    return inventory;
  }

  static getById(id: string): Product | undefined {
    return products.get(id);
  }

  static getAll(
    category?: string,
    minPrice?: number,
    maxPrice?: number
  ): Product[] {
    let result = Array.from(products.values());

    if (category) {
      result = result.filter(
        (p) => p.category.toLowerCase() === category.toLowerCase()
      );
    }

    if (minPrice !== undefined) {
      result = result.filter((p) => p.price >= minPrice);
    }

    if (maxPrice !== undefined) {
      result = result.filter((p) => p.price <= maxPrice);
    }

    return result;
  }

  static create(
    productData: Omit<Product, "id" | "createdAt" | "updatedAt">
  ): Product {
    const id = (products.size + 1).toString();
    const now = Date.now();
    const product: Product = {
      id,
      ...productData,
      createdAt: now,
      updatedAt: now,
    };
    products.set(id, product);
    return product;
  }

  static update(id: string, productData: Partial<Product>): Product | null {
    const existing = products.get(id);
    if (!existing) return null;

    // Filter out id and createdAt from update data to prevent overwriting
    const {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      id: _id,
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      createdAt: _createdAt,
      ...safeUpdateData
    } = productData;

    const updated: Product = {
      ...existing,
      ...safeUpdateData,
      updatedAt: Date.now(),
    };
    products.set(id, updated);
    return updated;
  }

  static delete(id: string): boolean {
    inventory.delete(id); // Also remove inventory
    return products.delete(id);
  }

  static paginate(
    pageSize: number,
    pageToken: string,
    category?: string,
    minPrice?: number,
    maxPrice?: number
  ): { products: Product[]; nextPageToken: string; totalCount: number } {
    const allProducts = this.getAll(category, minPrice, maxPrice);
    let startIndex = 0;

    if (pageToken) {
      const parsedToken = parseInt(pageToken);
      // Only use parsed token if it's a valid number, otherwise start from beginning
      if (!isNaN(parsedToken) && parsedToken >= 0) {
        startIndex = parsedToken;
      }
    }

    const endIndex = startIndex + pageSize;

    const paginatedProducts = allProducts.slice(startIndex, endIndex);
    const nextPageToken =
      endIndex < allProducts.length ? endIndex.toString() : "";

    return {
      products: paginatedProducts,
      nextPageToken,
      totalCount: allProducts.length,
    };
  }

  static getInventory(productId: string): Inventory[] {
    return inventory.get(productId) || [];
  }

  static getTotalQuantity(productId: string): number {
    const inv = this.getInventory(productId);
    return inv.reduce((total, item) => total + item.quantity, 0);
  }
}
