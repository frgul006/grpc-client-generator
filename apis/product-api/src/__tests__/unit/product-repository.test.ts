/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { ProductRepository, Product, Inventory } from '../../data/products';

describe('ProductRepository', () => {
  let originalProducts: Map<string, Product>;
  let originalInventory: Map<string, Inventory[]>;

  beforeEach(() => {
    // Store reference to original data for restoration
    originalProducts = new Map(ProductRepository.products);
    originalInventory = new Map(ProductRepository.inventory);
    
    // Clear repository before each test
    ProductRepository.products.clear();
    ProductRepository.inventory.clear();
    
    // Add test products
    const testProducts: Product[] = [
      {
        id: '1',
        name: 'Test Laptop',
        description: 'A test laptop for testing',
        price: 999.99,
        category: 'Electronics',
        sku: 'TEST-LAPTOP-001',
        createdAt: Date.now() - 86400000,
        updatedAt: Date.now() - 86400000
      },
      {
        id: '2',
        name: 'Test Phone',
        description: 'A test phone for testing',
        price: 599.99,
        category: 'Electronics',
        sku: 'TEST-PHONE-001',
        createdAt: Date.now() - 43200000,
        updatedAt: Date.now() - 43200000
      },
      {
        id: '3',
        name: 'Test Book',
        description: 'A test book for testing',
        price: 29.99,
        category: 'Books',
        sku: 'TEST-BOOK-001',
        createdAt: Date.now() - 21600000,
        updatedAt: Date.now() - 21600000
      }
    ];

    const testInventory: Inventory[] = [
      { productId: '1', quantity: 50, warehouseId: 'warehouse-test-1', lastRestocked: Date.now() - 7200000 },
      { productId: '1', quantity: 30, warehouseId: 'warehouse-test-2', lastRestocked: Date.now() - 3600000 },
      { productId: '2', quantity: 100, warehouseId: 'warehouse-test-1', lastRestocked: Date.now() - 1800000 },
      { productId: '3', quantity: 25, warehouseId: 'warehouse-test-1', lastRestocked: Date.now() - 900000 }
    ];

    testProducts.forEach(product => ProductRepository.products.set(product.id, product));
    testInventory.forEach(inv => {
      const existing = ProductRepository.inventory.get(inv.productId) || [];
      existing.push(inv);
      ProductRepository.inventory.set(inv.productId, existing);
    });
  });

  afterEach(() => {
    // Restore original data
    ProductRepository.products.clear();
    ProductRepository.inventory.clear();
    originalProducts.forEach((product, id) => ProductRepository.products.set(id, product));
    originalInventory.forEach((inventory, productId) => ProductRepository.inventory.set(productId, inventory));
  });

  describe('getById', () => {
    it('should return product when found', () => {
      const product = ProductRepository.getById('1');
      
      expect(product).toBeDefined();
      expect(product?.id).toBe('1');
      expect(product?.name).toBe('Test Laptop');
      expect(product?.description).toBe('A test laptop for testing');
      expect(product?.price).toBe(999.99);
      expect(product?.category).toBe('Electronics');
      expect(product?.sku).toBe('TEST-LAPTOP-001');
    });

    it('should return undefined when product not found', () => {
      const product = ProductRepository.getById('999');
      expect(product).toBeUndefined();
    });

    it('should return undefined for empty string id', () => {
      const product = ProductRepository.getById('');
      expect(product).toBeUndefined();
    });
  });

  describe('getAll', () => {
    it('should return all products when no filters provided', () => {
      const products = ProductRepository.getAll();
      
      expect(products).toHaveLength(3);
      expect(products.map(p => p.id)).toEqual(['1', '2', '3']);
    });

    it('should return empty array when no products exist', () => {
      ProductRepository.products.clear();
      const products = ProductRepository.getAll();
      
      expect(products).toHaveLength(0);
      expect(products).toEqual([]);
    });

    it('should filter products by category (case insensitive)', () => {
      const products = ProductRepository.getAll('electronics');
      
      expect(products).toHaveLength(2);
      expect(products.map(p => p.id)).toEqual(['1', '2']);
    });

    it('should filter products by category (exact case)', () => {
      const products = ProductRepository.getAll('Books');
      
      expect(products).toHaveLength(1);
      expect(products[0].id).toBe('3');
    });

    it('should filter products by minimum price', () => {
      const products = ProductRepository.getAll(undefined, 500);
      
      expect(products).toHaveLength(2);
      expect(products.map(p => p.id)).toEqual(['1', '2']);
    });

    it('should filter products by maximum price', () => {
      const products = ProductRepository.getAll(undefined, undefined, 100);
      
      expect(products).toHaveLength(1);
      expect(products[0].id).toBe('3');
    });

    it('should filter products by price range', () => {
      const products = ProductRepository.getAll(undefined, 500, 700);
      
      expect(products).toHaveLength(1);
      expect(products[0].id).toBe('2');
    });

    it('should filter products by category and price range', () => {
      const products = ProductRepository.getAll('Electronics', 500, 700);
      
      expect(products).toHaveLength(1);
      expect(products[0].id).toBe('2');
    });

    it('should return empty array when filters match nothing', () => {
      const products = ProductRepository.getAll('NonExistentCategory');
      
      expect(products).toHaveLength(0);
    });

    it('should return empty array when price range excludes all products', () => {
      const products = ProductRepository.getAll(undefined, 2000, 3000);
      
      expect(products).toHaveLength(0);
    });
  });

  describe('create', () => {
    it('should create new product with generated id and timestamps', () => {
      const productData = {
        name: 'New Test Product',
        description: 'A new test product',
        price: 199.99,
        category: 'Test Category',
        sku: 'NEW-TEST-001'
      };

      const product = ProductRepository.create(productData);

      expect(product.id).toBeDefined();
      expect(product.id).toBe('4'); // Next sequential ID
      expect(product.name).toBe('New Test Product');
      expect(product.description).toBe('A new test product');
      expect(product.price).toBe(199.99);
      expect(product.category).toBe('Test Category');
      expect(product.sku).toBe('NEW-TEST-001');
      expect(product.createdAt).toBeDefined();
      expect(product.updatedAt).toBeDefined();
      expect(product.createdAt).toBe(product.updatedAt);
    });

    it('should store created product in repository', () => {
      const productData = {
        name: 'Stored Product',
        description: 'A stored product',
        price: 299.99,
        category: 'Storage',
        sku: 'STORED-001'
      };

      const product = ProductRepository.create(productData);
      const retrieved = ProductRepository.getById(product.id);

      expect(retrieved).toEqual(product);
    });

    it('should generate sequential IDs', () => {
      const product1 = ProductRepository.create({
        name: 'Product 1',
        description: 'First product',
        price: 100,
        category: 'Test',
        sku: 'PROD-001'
      });

      const product2 = ProductRepository.create({
        name: 'Product 2',
        description: 'Second product',
        price: 200,
        category: 'Test',
        sku: 'PROD-002'
      });

      expect(parseInt(product1.id)).toBeLessThan(parseInt(product2.id));
      expect(parseInt(product2.id) - parseInt(product1.id)).toBe(1);
    });

    it('should set timestamps correctly', () => {
      const beforeCreate = Date.now();
      const product = ProductRepository.create({
        name: 'Timestamp Product',
        description: 'Testing timestamps',
        price: 150,
        category: 'Time',
        sku: 'TIME-001'
      });
      const afterCreate = Date.now();

      expect(product.createdAt).toBeGreaterThanOrEqual(beforeCreate);
      expect(product.createdAt).toBeLessThanOrEqual(afterCreate);
      expect(product.updatedAt).toBe(product.createdAt);
    });
  });

  describe('update', () => {
    it('should update existing product and return updated product', () => {
      const updateData = {
        name: 'Updated Laptop',
        description: 'An updated laptop',
        price: 1199.99,
        category: 'Updated Electronics'
      };

      const product = ProductRepository.update('1', updateData);

      expect(product).toBeDefined();
      expect(product?.id).toBe('1');
      expect(product?.name).toBe('Updated Laptop');
      expect(product?.description).toBe('An updated laptop');
      expect(product?.price).toBe(1199.99);
      expect(product?.category).toBe('Updated Electronics');
      expect(product?.sku).toBe('TEST-LAPTOP-001'); // Should remain unchanged
      expect(product?.updatedAt).toBeGreaterThan(product!.createdAt);
    });

    it('should preserve original createdAt timestamp', () => {
      const original = ProductRepository.getById('1');
      const originalCreatedAt = original!.createdAt;

      const product = ProductRepository.update('1', { name: 'Updated Name' });

      expect(product?.createdAt).toBe(originalCreatedAt);
    });

    it('should update only provided fields', () => {
      const original = ProductRepository.getById('1');
      
      const product = ProductRepository.update('1', { name: 'New Name Only' });

      expect(product?.name).toBe('New Name Only');
      expect(product?.description).toBe(original?.description);
      expect(product?.price).toBe(original?.price);
      expect(product?.category).toBe(original?.category);
      expect(product?.sku).toBe(original?.sku);
    });

    it('should return null when product not found', () => {
      const product = ProductRepository.update('999', { name: 'No Product' });
      expect(product).toBeNull();
    });

    it('should update updatedAt timestamp', () => {
      const original = ProductRepository.getById('1');
      const originalUpdatedAt = original!.updatedAt;

      // Small delay to ensure timestamp difference
      setTimeout(() => {
        const product = ProductRepository.update('1', { name: 'Updated' });
        expect(product?.updatedAt).toBeGreaterThan(originalUpdatedAt);
      }, 1);
    });

    it('should handle empty update data', () => {
      const original = ProductRepository.getById('1');
      const product = ProductRepository.update('1', {});

      expect(product?.name).toBe(original?.name);
      expect(product?.description).toBe(original?.description);
      expect(product?.price).toBe(original?.price);
      expect(product?.category).toBe(original?.category);
      expect(product?.sku).toBe(original?.sku);
      expect(product?.updatedAt).toBeGreaterThan(original!.updatedAt);
    });

    it('should not allow updating id or createdAt', () => {
      const original = ProductRepository.getById('1');
      const updateData = {
        name: 'New Name',
        // These should not be updatable
        id: '999',
        createdAt: Date.now() + 1000000
      } as any;

      const product = ProductRepository.update('1', updateData);

      expect(product?.id).toBe('1'); // Should remain unchanged
      expect(product?.createdAt).toBe(original?.createdAt); // Should remain unchanged
      expect(product?.name).toBe('New Name'); // Should be updated
    });
  });

  describe('delete', () => {
    it('should delete existing product and return true', () => {
      const result = ProductRepository.delete('1');
      
      expect(result).toBe(true);
      expect(ProductRepository.getById('1')).toBeUndefined();
    });

    it('should return false when product not found', () => {
      const result = ProductRepository.delete('999');
      expect(result).toBe(false);
    });

    it('should not affect other products when deleting', () => {
      ProductRepository.delete('2');
      
      expect(ProductRepository.getById('1')).toBeDefined();
      expect(ProductRepository.getById('3')).toBeDefined();
      expect(ProductRepository.getById('2')).toBeUndefined();
    });

    it('should reduce total product count', () => {
      const beforeCount = ProductRepository.getAll().length;
      ProductRepository.delete('1');
      const afterCount = ProductRepository.getAll().length;

      expect(afterCount).toBe(beforeCount - 1);
    });

    it('should also remove inventory when deleting product', () => {
      // Verify inventory exists before deletion
      const inventoryBefore = ProductRepository.getInventory('1');
      expect(inventoryBefore).toHaveLength(2);

      ProductRepository.delete('1');

      // Verify inventory is removed after deletion
      const inventoryAfter = ProductRepository.getInventory('1');
      expect(inventoryAfter).toHaveLength(0);
    });
  });

  describe('paginate', () => {
    it('should return first page with specified page size', () => {
      const result = ProductRepository.paginate(2, '');

      expect(result.products).toHaveLength(2);
      expect(result.totalCount).toBe(3);
      expect(result.nextPageToken).toBe('2');
      expect(result.products.map(p => p.id)).toEqual(['1', '2']);
    });

    it('should return second page when page token provided', () => {
      const result = ProductRepository.paginate(2, '2');

      expect(result.products).toHaveLength(1);
      expect(result.totalCount).toBe(3);
      expect(result.nextPageToken).toBe('');
      expect(result.products[0].id).toBe('3');
    });

    it('should return empty next page token when no more pages', () => {
      const result = ProductRepository.paginate(5, '');

      expect(result.products).toHaveLength(3);
      expect(result.nextPageToken).toBe('');
      expect(result.totalCount).toBe(3);
    });

    it('should handle page size larger than total products', () => {
      const result = ProductRepository.paginate(10, '');

      expect(result.products).toHaveLength(3);
      expect(result.nextPageToken).toBe('');
      expect(result.totalCount).toBe(3);
    });

    it('should handle invalid page token gracefully', () => {
      const result = ProductRepository.paginate(2, 'invalid');

      expect(result.products).toHaveLength(2);
      expect(result.totalCount).toBe(3);
    });

    it('should handle zero page size', () => {
      const result = ProductRepository.paginate(0, '');

      expect(result.products).toHaveLength(0);
      expect(result.nextPageToken).toBe('0');
      expect(result.totalCount).toBe(3);
    });

    it('should handle page token beyond available data', () => {
      const result = ProductRepository.paginate(2, '10');

      expect(result.products).toHaveLength(0);
      expect(result.nextPageToken).toBe('');
      expect(result.totalCount).toBe(3);
    });

    it('should return products in consistent order', () => {
      const page1 = ProductRepository.paginate(1, '');
      const page2 = ProductRepository.paginate(1, '1');
      const page3 = ProductRepository.paginate(1, '2');

      expect(page1.products[0].id).toBe('1');
      expect(page2.products[0].id).toBe('2');
      expect(page3.products[0].id).toBe('3');
    });

    it('should apply filters when paginating', () => {
      const result = ProductRepository.paginate(2, '', 'Electronics');

      expect(result.products).toHaveLength(2);
      expect(result.totalCount).toBe(2);
      expect(result.nextPageToken).toBe('');
      expect(result.products.every(p => p.category === 'Electronics')).toBe(true);
    });

    it('should apply price filters when paginating', () => {
      const result = ProductRepository.paginate(5, '', undefined, 500);

      expect(result.products).toHaveLength(2);
      expect(result.totalCount).toBe(2);
      expect(result.products.every(p => p.price >= 500)).toBe(true);
    });
  });

  describe('inventory management', () => {
    describe('getInventory', () => {
      it('should return inventory for existing product', () => {
        const inventory = ProductRepository.getInventory('1');
        
        expect(inventory).toHaveLength(2);
        expect(inventory[0].productId).toBe('1');
        expect(inventory[0].quantity).toBe(50);
        expect(inventory[0].warehouseId).toBe('warehouse-test-1');
        expect(inventory[1].productId).toBe('1');
        expect(inventory[1].quantity).toBe(30);
        expect(inventory[1].warehouseId).toBe('warehouse-test-2');
      });

      it('should return empty array for product with no inventory', () => {
        const inventory = ProductRepository.getInventory('999');
        expect(inventory).toEqual([]);
      });

      it('should return empty array for non-existent product', () => {
        const inventory = ProductRepository.getInventory('non-existent');
        expect(inventory).toEqual([]);
      });
    });

    describe('getTotalQuantity', () => {
      it('should return total quantity across all warehouses', () => {
        const totalQuantity = ProductRepository.getTotalQuantity('1');
        expect(totalQuantity).toBe(80); // 50 + 30
      });

      it('should return correct quantity for single warehouse product', () => {
        const totalQuantity = ProductRepository.getTotalQuantity('2');
        expect(totalQuantity).toBe(100);
      });

      it('should return 0 for product with no inventory', () => {
        const totalQuantity = ProductRepository.getTotalQuantity('999');
        expect(totalQuantity).toBe(0);
      });

      it('should return 0 for non-existent product', () => {
        const totalQuantity = ProductRepository.getTotalQuantity('non-existent');
        expect(totalQuantity).toBe(0);
      });
    });
  });

  describe('integration scenarios', () => {
    it('should handle full CRUD cycle', () => {
      // Create
      const newProduct = ProductRepository.create({
        name: 'CRUD Product',
        description: 'A product for CRUD testing',
        price: 299.99,
        category: 'Test',
        sku: 'CRUD-001'
      });
      expect(newProduct.id).toBeDefined();

      // Read
      const retrieved = ProductRepository.getById(newProduct.id);
      expect(retrieved).toEqual(newProduct);

      // Update
      const updated = ProductRepository.update(newProduct.id, {
        name: 'Updated CRUD Product',
        price: 399.99
      });
      expect(updated?.name).toBe('Updated CRUD Product');
      expect(updated?.price).toBe(399.99);

      // Delete
      const deleted = ProductRepository.delete(newProduct.id);
      expect(deleted).toBe(true);
      expect(ProductRepository.getById(newProduct.id)).toBeUndefined();
    });

    it('should maintain data consistency across operations', () => {
      const initialCount = ProductRepository.getAll().length;

      // Create product
      const newProduct = ProductRepository.create({
        name: 'Consistency Product',
        description: 'Testing consistency',
        price: 199.99,
        category: 'Test',
        sku: 'CONSISTENCY-001'
      });

      expect(ProductRepository.getAll().length).toBe(initialCount + 1);

      // Update product
      ProductRepository.update(newProduct.id, { name: 'Updated' });
      expect(ProductRepository.getAll().length).toBe(initialCount + 1);

      // Delete product
      ProductRepository.delete(newProduct.id);
      expect(ProductRepository.getAll().length).toBe(initialCount);
    });

    it('should handle filtering and pagination together', () => {
      // Add more test data
      ProductRepository.create({
        name: 'Extra Electronics 1',
        description: 'Extra electronics product',
        price: 799.99,
        category: 'Electronics',
        sku: 'EXTRA-ELEC-001'
      });

      ProductRepository.create({
        name: 'Extra Electronics 2',
        description: 'Another extra electronics product',
        price: 899.99,
        category: 'Electronics',
        sku: 'EXTRA-ELEC-002'
      });

      // Test filtered pagination
      const result = ProductRepository.paginate(2, '', 'Electronics', 600);
      
      expect(result.products).toHaveLength(2);
      expect(result.totalCount).toBe(3); // 1 original + 2 new Electronics products with price >= 600 (Test Phone is 599.99 < 600)
      expect(result.nextPageToken).toBe('2');
      expect(result.products.every(p => p.category === 'Electronics' && p.price >= 600)).toBe(true);
    });
  });
});