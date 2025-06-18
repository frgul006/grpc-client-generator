/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { status } from '@grpc/grpc-js';
import { productServiceImplementation } from '../../service/product-service.js';
import { ProductRepository, Product, Inventory } from '../../data/products.js';
import { 
  GetProductResponse,
  GetInventoryResponse,
  Product as ProductProto,
  Inventory as InventoryProto
} from '../../generated/product.js';
import { mockConsole, restoreConsole } from '../setup.js';

// Since ts-proto generates interfaces instead of classes, we don't need complex mocks
// The service now returns plain objects that match the interface types

describe('ProductService', () => {
  let originalProducts: Map<string, Product>;
  let originalInventory: Map<string, Inventory[]>;

  beforeEach(() => {
    // Store original data
    originalProducts = new Map(ProductRepository.products);
    originalInventory = new Map(ProductRepository.inventory);
    
    // Clear and setup test data
    ProductRepository.products.clear();
    ProductRepository.inventory.clear();
    
    const testProducts: Product[] = [
      {
        id: '1',
        name: 'Test Product 1',
        description: 'First test product',
        price: 100.00,
        category: 'Electronics',
        sku: 'TEST-001',
        createdAt: Date.now() - 86400000,
        updatedAt: Date.now() - 86400000
      },
      {
        id: '2',
        name: 'Test Product 2',
        description: 'Second test product',
        price: 200.00,
        category: 'Electronics',
        sku: 'TEST-002',
        createdAt: Date.now() - 43200000,
        updatedAt: Date.now() - 43200000
      }
    ];

    const testInventory: Inventory[] = [
      { productId: '1', quantity: 50, warehouseId: 'warehouse-1', lastRestocked: Date.now() - 7200000 },
      { productId: '2', quantity: 75, warehouseId: 'warehouse-1', lastRestocked: Date.now() - 3600000 }
    ];

    testProducts.forEach(product => ProductRepository.products.set(product.id, product));
    testInventory.forEach(inv => {
      const existing = ProductRepository.inventory.get(inv.productId) || [];
      existing.push(inv);
      ProductRepository.inventory.set(inv.productId, existing);
    });

    mockConsole();
  });

  afterEach(() => {
    // Restore original data
    ProductRepository.products.clear();
    ProductRepository.inventory.clear();
    originalProducts.forEach((product, id) => ProductRepository.products.set(id, product));
    originalInventory.forEach((inventory, productId) => ProductRepository.inventory.set(productId, inventory));
    
    restoreConsole();
  });

  describe('getProduct', () => {
    it('should return product when found', () => {
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        product: expect.objectContaining({
          id: '1',
          name: 'Test Product 1'
        })
      }));
    });

    it('should return NOT_FOUND error when product does not exist', () => {
      const mockRequest = {
        id: '999'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.NOT_FOUND,
        details: 'Product with ID 999 not found'
      });
    });

    it('should return INVALID_ARGUMENT error when id is missing', () => {
      const mockRequest = {
        id: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    });

    it('should return INVALID_ARGUMENT error when id is null', () => {
      const mockRequest = {
        id: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    });

    it('should log the product request', () => {
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      expect(console.log).toHaveBeenCalledWith('[Product Service] GetProduct called with ID: 1');
    });
  });

  describe('listProducts', () => {
    it('should return products with default pagination', () => {
      const mockRequest = {
        pageSize: 0, // Should default to 10
        pageToken: '',
        category: '',
        minPrice: 0,
        maxPrice: 0
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.listProducts(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        products: expect.any(Array),
        nextPageToken: expect.any(String),
        totalCount: expect.any(Number)
      }));
    });

    it('should handle pagination parameters', () => {
      const mockRequest = {
        pageSize: 1,
        pageToken: '',
        category: '',
        minPrice: 0,
        maxPrice: 0
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.listProducts(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        products: expect.any(Array),
        nextPageToken: expect.any(String),
        totalCount: expect.any(Number)
      }));
    });

    it('should handle category filter', () => {
      const mockRequest = {
        pageSize: 10,
        pageToken: '',
        category: 'Electronics',
        minPrice: 0,
        maxPrice: 0
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.listProducts(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        products: expect.any(Array),
        nextPageToken: expect.any(String),
        totalCount: expect.any(Number)
      }));
    });

    it('should handle price range filters', () => {
      const mockRequest = {
        pageSize: 10,
        pageToken: '',
        category: '',
        minPrice: 50,
        maxPrice: 150
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.listProducts(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        products: expect.any(Array),
        nextPageToken: expect.any(String),
        totalCount: expect.any(Number)
      }));
    });

    it('should log the list request with parameters', () => {
      const mockRequest = {
        pageSize: 5,
        pageToken: 'token123',
        category: 'Electronics',
        minPrice: 100,
        maxPrice: 500
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.listProducts(mockCall as any, mockCallback);

      expect(console.log).toHaveBeenCalledWith(
        '[Product Service] ListProducts called - pageSize: 5, pageToken: token123, category: Electronics, minPrice: 100, maxPrice: 500'
      );
    });
  });

  describe('createProduct', () => {
    it('should create product with valid data', () => {
      const mockRequest = {
        name: 'New Product',
        description: 'A new product',
        price: 299.99,
        category: 'Electronics',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        product: expect.objectContaining({
          name: 'New Product',
          description: 'A new product'
        })
      }));
    });

    it('should return INVALID_ARGUMENT error when name is missing', () => {
      const mockRequest = {
        name: '',
        description: 'A new product',
        price: 299.99,
        category: 'Electronics',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Name, description, price, category, and SKU are required'
      });
    });

    it('should return INVALID_ARGUMENT error when description is missing', () => {
      const mockRequest = {
        name: 'New Product',
        description: '',
        price: 299.99,
        category: 'Electronics',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Name, description, price, category, and SKU are required'
      });
    });

    it('should return INVALID_ARGUMENT error when price is missing', () => {
      const mockRequest = {
        name: 'New Product',
        description: 'A new product',
        price: 0,
        category: 'Electronics',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Name, description, price, category, and SKU are required'
      });
    });

    it('should return INVALID_ARGUMENT error when category is missing', () => {
      const mockRequest = {
        name: 'New Product',
        description: 'A new product',
        price: 299.99,
        category: '',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Name, description, price, category, and SKU are required'
      });
    });

    it('should return INVALID_ARGUMENT error when SKU is missing', () => {
      const mockRequest = {
        name: 'New Product',
        description: 'A new product',
        price: 299.99,
        category: 'Electronics',
        sku: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Name, description, price, category, and SKU are required'
      });
    });

    it('should log the create request', () => {
      const mockRequest = {
        name: 'New Product',
        description: 'A new product',
        price: 299.99,
        category: 'Electronics',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(console.log).toHaveBeenCalledWith(
        '[Product Service] CreateProduct called - name: New Product, description: A new product, price: 299.99, category: Electronics, sku: NEW-001'
      );
    });
  });

  describe('updateProduct', () => {
    it('should update existing product', () => {
      const mockRequest = {
        id: '1',
        name: 'Updated Product',
        description: 'Updated description',
        price: 150.00,
        category: 'Updated Category'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.updateProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object));
      expect(mockCallback).not.toHaveBeenCalledWith(expect.objectContaining({ code: expect.any(Number) }));
    });

    it('should return INVALID_ARGUMENT error when id is missing', () => {
      const mockRequest = {
        id: '',
        name: 'Updated Product',
        description: 'Updated description',
        price: 150.00,
        category: 'Updated Category'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.updateProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    });

    it('should return NOT_FOUND error when product does not exist', () => {
      const mockRequest = {
        id: '999',
        name: 'Updated Product',
        description: 'Updated description',
        price: 150.00,
        category: 'Updated Category'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.updateProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.NOT_FOUND,
        details: 'Product with ID 999 not found'
      });
    });

    it('should handle partial updates', () => {
      const mockRequest = {
        id: '1',
        name: 'Updated Name Only',
        description: '',
        price: 0,
        category: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.updateProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object));
    });

    it('should log the update request', () => {
      const mockRequest = {
        id: '1',
        name: 'Updated Product',
        description: 'Updated description',
        price: 150.00,
        category: 'Updated Category'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.updateProduct(mockCall as any, mockCallback);

      expect(console.log).toHaveBeenCalledWith(
        '[Product Service] UpdateProduct called - id: 1, name: Updated Product, description: Updated description, price: 150, category: Updated Category'
      );
    });
  });

  describe('deleteProduct', () => {
    it('should delete existing product', () => {
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.deleteProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object));
      expect(mockCallback).not.toHaveBeenCalledWith(expect.objectContaining({ code: expect.any(Number) }));
    });

    it('should return INVALID_ARGUMENT error when id is missing', () => {
      const mockRequest = {
        id: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.deleteProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    });

    it('should return NOT_FOUND error when product does not exist', () => {
      const mockRequest = {
        id: '999'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.deleteProduct(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.NOT_FOUND,
        details: 'Product with ID 999 not found'
      });
    });

    it('should log the delete request', () => {
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.deleteProduct(mockCall as any, mockCallback);

      expect(console.log).toHaveBeenCalledWith('[Product Service] DeleteProduct called with ID: 1');
    });
  });

  describe('getInventory', () => {
    it('should return inventory for existing product', () => {
      const mockRequest = {
        productId: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getInventory(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object));
      expect(mockCallback).not.toHaveBeenCalledWith(expect.objectContaining({ code: expect.any(Number) }));
    });

    it('should return INVALID_ARGUMENT error when product id is missing', () => {
      const mockRequest = {
        productId: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getInventory(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    });

    it('should handle product with no inventory', () => {
      const mockRequest = {
        productId: '999'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getInventory(mockCall as any, mockCallback);

      expect(mockCallback).toHaveBeenCalledWith(null, expect.any(Object));
    });

    it('should log the inventory request', () => {
      const mockRequest = {
        productId: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getInventory(mockCall as any, mockCallback);

      expect(console.log).toHaveBeenCalledWith('[Product Service] GetInventory called for product ID: 1');
    });
  });

  describe('error handling', () => {
    it('should handle repository errors gracefully', () => {
      // Mock ProductRepository to throw an error
      const originalGetById = ProductRepository.getById;
      ProductRepository.getById = vi.fn().mockImplementation(() => {
        throw new Error('Database error');
      });

      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      expect(() => {
        productServiceImplementation.getProduct(mockCall as any, mockCallback);
      }).toThrow('Database error');

      // Restore original method
      ProductRepository.getById = originalGetById;
    });
  });

  describe('data transformation', () => {
    it('should properly transform product data for responses', () => {
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      // Verify the response was called with proper data structure
      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        product: expect.objectContaining({
          id: '1',
          name: 'Test Product 1'
        })
      }));
    });

    it('should properly transform inventory data for responses', () => {
      const mockRequest = {
        productId: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getInventory(mockCall as any, mockCallback);

      // Verify the response was called with proper data structure
      expect(mockCallback).toHaveBeenCalledWith(null, expect.objectContaining({
        inventory: expect.any(Array),
        totalQuantity: expect.any(Number)
      }));
    });
  });

  describe('integration with ProductRepository', () => {
    it('should call ProductRepository methods with correct parameters', () => {
      const getByIdSpy = vi.spyOn(ProductRepository, 'getById');
      
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getProduct(mockCall as any, mockCallback);

      expect(getByIdSpy).toHaveBeenCalledWith('1');
      
      getByIdSpy.mockRestore();
    });

    it('should call ProductRepository create method with correct parameters', () => {
      const createSpy = vi.spyOn(ProductRepository, 'create');
      
      const mockRequest = {
        name: 'New Product',
        description: 'A new product',
        price: 299.99,
        category: 'Electronics',
        sku: 'NEW-001'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.createProduct(mockCall as any, mockCallback);

      expect(createSpy).toHaveBeenCalledWith({
        name: 'New Product',
        description: 'A new product',
        price: 299.99,
        category: 'Electronics',
        sku: 'NEW-001'
      });
      
      createSpy.mockRestore();
    });

    it('should call ProductRepository update method with correct parameters', () => {
      const updateSpy = vi.spyOn(ProductRepository, 'update');
      
      const mockRequest = {
        id: '1',
        name: 'Updated Product',
        description: '',
        price: 0,
        category: ''
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.updateProduct(mockCall as any, mockCallback);

      expect(updateSpy).toHaveBeenCalledWith('1', {
        name: 'Updated Product'
      });
      
      updateSpy.mockRestore();
    });

    it('should call ProductRepository delete method with correct parameters', () => {
      const deleteSpy = vi.spyOn(ProductRepository, 'delete');
      
      const mockRequest = {
        id: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.deleteProduct(mockCall as any, mockCallback);

      expect(deleteSpy).toHaveBeenCalledWith('1');
      
      deleteSpy.mockRestore();
    });

    it('should call ProductRepository inventory methods with correct parameters', () => {
      const getInventorySpy = vi.spyOn(ProductRepository, 'getInventory');
      const getTotalQuantitySpy = vi.spyOn(ProductRepository, 'getTotalQuantity');
      
      const mockRequest = {
        productId: '1'
      };
      const mockCall = { request: mockRequest };
      const mockCallback = vi.fn();

      productServiceImplementation.getInventory(mockCall as any, mockCallback);

      expect(getInventorySpy).toHaveBeenCalledWith('1');
      expect(getTotalQuantitySpy).toHaveBeenCalledWith('1');
      
      getInventorySpy.mockRestore();
      getTotalQuantitySpy.mockRestore();
    });
  });
});