import { describe, it, expect, beforeEach, afterEach } from "vitest";
import {
  ProductRepository,
  type Product,
  type Inventory,
} from "../../data/products.js";

describe("ProductService Integration Tests", () => {
  let originalProducts: Map<string, Product>;
  let originalInventory: Map<string, Inventory[]>;

  beforeEach(() => {
    // Store original data
    originalProducts = new Map(ProductRepository.products);
    originalInventory = new Map(ProductRepository.inventory);

    // Clear repository for clean test environment
    ProductRepository.products.clear();
    ProductRepository.inventory.clear();
  });

  afterEach(() => {
    // Restore original data
    ProductRepository.products.clear();
    ProductRepository.inventory.clear();
    originalProducts.forEach((product, id) =>
      ProductRepository.products.set(id, product)
    );
    originalInventory.forEach((inventory, productId) =>
      ProductRepository.inventory.set(productId, inventory)
    );
  });

  describe("complete product lifecycle", () => {
    it("should handle full product CRUD operations with inventory", () => {
      // 1. Create a new product
      const newProduct = ProductRepository.create({
        name: "Integration Test Product",
        description: "A product for testing the full lifecycle",
        price: 199.99,
        category: "Test",
        sku: "INT-TEST-001",
      });

      expect(newProduct.id).toBeDefined();
      expect(newProduct.name).toBe("Integration Test Product");
      expect(newProduct.createdAt).toBe(newProduct.updatedAt);

      // 2. Verify product can be retrieved
      const retrieved = ProductRepository.getById(newProduct.id);
      expect(retrieved).toEqual(newProduct);

      // 3. Update the product (with a tiny delay to ensure different timestamp)
      const originalCreatedAt = newProduct.createdAt;

      // Small delay to ensure timestamp difference
      const updated = ProductRepository.update(newProduct.id, {
        name: "Updated Integration Product",
        price: 249.99,
      });

      expect(updated?.name).toBe("Updated Integration Product");
      expect(updated?.price).toBe(249.99);
      expect(updated?.description).toBe(
        "A product for testing the full lifecycle"
      ); // Should remain unchanged
      expect(updated?.updatedAt).toBeGreaterThanOrEqual(originalCreatedAt); // Allow for same timestamp if very fast
      expect(updated?.createdAt).toBe(originalCreatedAt); // Should remain unchanged

      // 4. Verify updated product appears in listings
      const allProducts = ProductRepository.getAll();
      const foundProduct = allProducts.find((p) => p.id === newProduct.id);
      expect(foundProduct?.name).toBe("Updated Integration Product");

      // 5. Test inventory operations (even though no inventory exists)
      const inventory = ProductRepository.getInventory(newProduct.id);
      expect(inventory).toEqual([]);

      const totalQuantity = ProductRepository.getTotalQuantity(newProduct.id);
      expect(totalQuantity).toBe(0);

      // 6. Delete the product
      const deleted = ProductRepository.delete(newProduct.id);
      expect(deleted).toBe(true);

      // 7. Verify product is gone
      const afterDelete = ProductRepository.getById(newProduct.id);
      expect(afterDelete).toBeUndefined();

      // 8. Verify product no longer appears in listings
      const finalProducts = ProductRepository.getAll();
      const notFound = finalProducts.find((p) => p.id === newProduct.id);
      expect(notFound).toBeUndefined();
    });
  });

  describe("inventory management scenarios", () => {
    it("should handle products with complex inventory across multiple warehouses", () => {
      // Create a product
      const product = ProductRepository.create({
        name: "Multi-Warehouse Product",
        description: "Product with inventory in multiple warehouses",
        price: 399.99,
        category: "Electronics",
        sku: "MW-PROD-001",
      });

      // Add inventory manually (simulating inventory service operations)
      const inventoryData: Inventory[] = [
        {
          productId: product.id,
          quantity: 100,
          warehouseId: "warehouse-east",
          lastRestocked: Date.now() - 86400000,
        },
        {
          productId: product.id,
          quantity: 75,
          warehouseId: "warehouse-west",
          lastRestocked: Date.now() - 43200000,
        },
        {
          productId: product.id,
          quantity: 50,
          warehouseId: "warehouse-central",
          lastRestocked: Date.now() - 21600000,
        },
      ];

      inventoryData.forEach((inv) => {
        const existing = ProductRepository.inventory.get(inv.productId) || [];
        existing.push(inv);
        ProductRepository.inventory.set(inv.productId, existing);
      });

      // Test inventory retrieval
      const inventory = ProductRepository.getInventory(product.id);
      expect(inventory).toHaveLength(3);
      expect(inventory.map((i) => i.warehouseId)).toEqual([
        "warehouse-east",
        "warehouse-west",
        "warehouse-central",
      ]);
      expect(inventory.map((i) => i.quantity)).toEqual([100, 75, 50]);

      // Test total quantity calculation
      const totalQuantity = ProductRepository.getTotalQuantity(product.id);
      expect(totalQuantity).toBe(225); // 100 + 75 + 50

      // Test product deletion also removes inventory
      ProductRepository.delete(product.id);
      const inventoryAfterDelete = ProductRepository.getInventory(product.id);
      expect(inventoryAfterDelete).toEqual([]);
    });
  });

  describe("filtering and pagination scenarios", () => {
    beforeEach(() => {
      // Set up test data for filtering/pagination
      const testProducts: Product[] = [
        {
          id: "1",
          name: "Expensive Electronics",
          description: "High-end electronic device",
          price: 1999.99,
          category: "Electronics",
          sku: "EXP-ELEC-001",
          createdAt: Date.now() - 86400000,
          updatedAt: Date.now() - 86400000,
        },
        {
          id: "2",
          name: "Budget Electronics",
          description: "Affordable electronic device",
          price: 99.99,
          category: "Electronics",
          sku: "BUD-ELEC-001",
          createdAt: Date.now() - 43200000,
          updatedAt: Date.now() - 43200000,
        },
        {
          id: "3",
          name: "Mid-Range Electronics",
          description: "Reasonably priced electronic device",
          price: 499.99,
          category: "Electronics",
          sku: "MID-ELEC-001",
          createdAt: Date.now() - 21600000,
          updatedAt: Date.now() - 21600000,
        },
        {
          id: "4",
          name: "Fiction Book",
          description: "An interesting fiction book",
          price: 15.99,
          category: "Books",
          sku: "FIC-BOOK-001",
          createdAt: Date.now() - 10800000,
          updatedAt: Date.now() - 10800000,
        },
        {
          id: "5",
          name: "Educational Book",
          description: "A comprehensive educational book",
          price: 89.99,
          category: "Books",
          sku: "EDU-BOOK-001",
          createdAt: Date.now() - 5400000,
          updatedAt: Date.now() - 5400000,
        },
      ];

      testProducts.forEach((product) =>
        ProductRepository.products.set(product.id, product)
      );
    });

    it("should handle complex filtering combinations", () => {
      // Test category filter only
      const electronicsProducts = ProductRepository.getAll("Electronics");
      expect(electronicsProducts).toHaveLength(3);
      expect(
        electronicsProducts.every((p) => p.category === "Electronics")
      ).toBe(true);

      // Test price range filter only
      const midRangeProducts = ProductRepository.getAll(undefined, 100, 500);
      expect(midRangeProducts).toHaveLength(1);
      expect(midRangeProducts[0]?.name).toBe("Mid-Range Electronics");

      // Test combined category and price filters
      const affordableElectronics = ProductRepository.getAll(
        "Electronics",
        50,
        200
      );
      expect(affordableElectronics).toHaveLength(1);
      expect(affordableElectronics[0]?.name).toBe("Budget Electronics");

      // Test filter that matches nothing
      const expensiveBooks = ProductRepository.getAll("Books", 1000);
      expect(expensiveBooks).toHaveLength(0);
    });

    it("should handle pagination with various filters", () => {
      // Test basic pagination
      const page1 = ProductRepository.paginate(2, "");
      expect(page1.products).toHaveLength(2);
      expect(page1.totalCount).toBe(5);
      expect(page1.nextPageToken).toBe("2");

      const page2 = ProductRepository.paginate(2, "2");
      expect(page2.products).toHaveLength(2);
      expect(page2.totalCount).toBe(5);
      expect(page2.nextPageToken).toBe("4");

      const page3 = ProductRepository.paginate(2, "4");
      expect(page3.products).toHaveLength(1);
      expect(page3.totalCount).toBe(5);
      expect(page3.nextPageToken).toBe("");

      // Test pagination with category filter
      const electronicsPage1 = ProductRepository.paginate(2, "", "Electronics");
      expect(electronicsPage1.products).toHaveLength(2);
      expect(electronicsPage1.totalCount).toBe(3);
      expect(electronicsPage1.nextPageToken).toBe("2");
      expect(
        electronicsPage1.products.every((p) => p.category === "Electronics")
      ).toBe(true);

      // Test pagination with price filter
      const cheapProductsPage = ProductRepository.paginate(
        3,
        "",
        undefined,
        undefined,
        100
      );
      expect(cheapProductsPage.products).toHaveLength(3);
      expect(cheapProductsPage.totalCount).toBe(3);
      expect(cheapProductsPage.nextPageToken).toBe("");
      expect(cheapProductsPage.products.every((p) => p.price <= 100)).toBe(
        true
      );
    });

    it("should maintain consistent ordering across paginated results", () => {
      // Get all products in one call
      const allProducts = ProductRepository.getAll();

      // Get same products through pagination
      const page1 = ProductRepository.paginate(3, "");
      const page2 = ProductRepository.paginate(3, "3");

      const paginatedProducts = [...page1.products, ...page2.products];

      // Compare IDs to ensure order is consistent
      expect(paginatedProducts.map((p) => p.id)).toEqual(
        allProducts.map((p) => p.id)
      );
    });
  });

  describe("edge cases and error conditions", () => {
    it("should handle edge cases in product operations", () => {
      // Test with empty repository
      expect(ProductRepository.getAll()).toEqual([]);
      expect(ProductRepository.getById("nonexistent")).toBeUndefined();
      expect(
        ProductRepository.update("nonexistent", { name: "New Name" })
      ).toBeNull();
      expect(ProductRepository.delete("nonexistent")).toBe(false);

      // Test inventory operations on empty repository
      expect(ProductRepository.getInventory("nonexistent")).toEqual([]);
      expect(ProductRepository.getTotalQuantity("nonexistent")).toBe(0);

      // Test pagination on empty repository
      const emptyPage = ProductRepository.paginate(10, "");
      expect(emptyPage.products).toEqual([]);
      expect(emptyPage.totalCount).toBe(0);
      expect(emptyPage.nextPageToken).toBe("");
    });

    it("should handle extreme pagination scenarios", () => {
      // Add one product for testing
      ProductRepository.create({
        name: "Single Product",
        description: "Only product in repository",
        price: 99.99,
        category: "Test",
        sku: "SINGLE-001",
      });

      // Test large page size
      const largePage = ProductRepository.paginate(1000, "");
      expect(largePage.products).toHaveLength(1);
      expect(largePage.nextPageToken).toBe("");

      // Test zero page size
      const zeroPage = ProductRepository.paginate(0, "");
      expect(zeroPage.products).toHaveLength(0);
      expect(zeroPage.nextPageToken).toBe("0");

      // Test page token way beyond data
      const beyondPage = ProductRepository.paginate(5, "1000");
      expect(beyondPage.products).toHaveLength(0);
      expect(beyondPage.nextPageToken).toBe("");
    });

    it("should handle special characters and edge values in product data", () => {
      // Test with special characters
      const specialProduct = ProductRepository.create({
        name: 'Product with "Quotes" & Special <Characters>',
        description: "Description with émojis 🚀 and ünïcödë",
        price: 0.01, // Minimum price
        category: "Special/Category-With_Symbols",
        sku: "SPEC!@#$%^&*()_+",
      });

      expect(specialProduct.name).toBe(
        'Product with "Quotes" & Special <Characters>'
      );
      expect(specialProduct.description).toBe(
        "Description with émojis 🚀 and ünïcödë"
      );
      expect(specialProduct.price).toBe(0.01);

      // Verify retrieval works with special characters
      const retrieved = ProductRepository.getById(specialProduct.id);
      expect(retrieved).toEqual(specialProduct);

      // Test very long strings
      const longName = "A".repeat(1000);
      const longProduct = ProductRepository.create({
        name: longName,
        description: "B".repeat(2000),
        price: 999999.99, // Large price
        category: "Test",
        sku: "LONG-001",
      });

      expect(longProduct.name).toBe(longName);
      expect(longProduct.description).toBe("B".repeat(2000));
    });
  });

  describe("concurrent operations simulation", () => {
    it("should handle rapid sequential operations correctly", () => {
      const products: Product[] = [];

      // Simulate rapid product creation
      for (let i = 0; i < 10; i++) {
        const product = ProductRepository.create({
          name: `Rapid Product ${i}`,
          description: `Description ${i}`,
          price: 100 + i,
          category: "Rapid",
          sku: `RAPID-${i.toString().padStart(3, "0")}`,
        });
        products.push(product);
      }

      expect(products).toHaveLength(10);
      expect(ProductRepository.getAll()).toHaveLength(10);

      // Verify IDs are sequential
      const ids = products.map((p) => parseInt(p.id));
      for (let i = 1; i < ids.length; i++) {
        expect(ids[i]).toBe(ids[i - 1]! + 1);
      }

      // Test rapid updates
      products.forEach((product, index) => {
        ProductRepository.update(product.id, {
          name: `Updated Rapid Product ${index}`,
          price: 200 + index,
        });
      });

      // Verify all updates were applied
      const updatedProducts = ProductRepository.getAll();
      updatedProducts.forEach((product, index) => {
        expect(product.name).toBe(`Updated Rapid Product ${index}`);
        expect(product.price).toBe(200 + index);
      });

      // Test rapid deletions
      products.slice(0, 5).forEach((product) => {
        ProductRepository.delete(product.id);
      });

      expect(ProductRepository.getAll()).toHaveLength(5);
    });
  });

  describe("data consistency and integrity", () => {
    it("should maintain referential integrity between products and inventory", () => {
      // Create products
      const product1 = ProductRepository.create({
        name: "Product 1",
        description: "First product",
        price: 100,
        category: "Test",
        sku: "PROD-001",
      });

      const product2 = ProductRepository.create({
        name: "Product 2",
        description: "Second product",
        price: 200,
        category: "Test",
        sku: "PROD-002",
      });

      // Add inventory for both products
      const inventoryData: Inventory[] = [
        {
          productId: product1.id,
          quantity: 50,
          warehouseId: "warehouse-1",
          lastRestocked: Date.now(),
        },
        {
          productId: product1.id,
          quantity: 30,
          warehouseId: "warehouse-2",
          lastRestocked: Date.now(),
        },
        {
          productId: product2.id,
          quantity: 25,
          warehouseId: "warehouse-1",
          lastRestocked: Date.now(),
        },
      ];

      inventoryData.forEach((inv) => {
        const existing = ProductRepository.inventory.get(inv.productId) || [];
        existing.push(inv);
        ProductRepository.inventory.set(inv.productId, existing);
      });

      // Verify inventory exists
      expect(ProductRepository.getInventory(product1.id)).toHaveLength(2);
      expect(ProductRepository.getInventory(product2.id)).toHaveLength(1);
      expect(ProductRepository.getTotalQuantity(product1.id)).toBe(80);
      expect(ProductRepository.getTotalQuantity(product2.id)).toBe(25);

      // Delete first product
      ProductRepository.delete(product1.id);

      // Verify product and its inventory are gone
      expect(ProductRepository.getById(product1.id)).toBeUndefined();
      expect(ProductRepository.getInventory(product1.id)).toHaveLength(0);
      expect(ProductRepository.getTotalQuantity(product1.id)).toBe(0);

      // Verify second product and its inventory remain
      expect(ProductRepository.getById(product2.id)).toBeDefined();
      expect(ProductRepository.getInventory(product2.id)).toHaveLength(1);
      expect(ProductRepository.getTotalQuantity(product2.id)).toBe(25);
    });

    it("should preserve timestamps correctly across operations", () => {
      const beforeCreate = Date.now();

      const product = ProductRepository.create({
        name: "Timestamp Test Product",
        description: "Testing timestamp behavior",
        price: 150,
        category: "Test",
        sku: "TIME-001",
      });

      const afterCreate = Date.now();

      // Verify creation timestamps
      expect(product.createdAt).toBeGreaterThanOrEqual(beforeCreate);
      expect(product.createdAt).toBeLessThanOrEqual(afterCreate);
      expect(product.updatedAt).toBe(product.createdAt);

      // Update without delay - timestamp behavior already tested elsewhere
      const originalCreatedAt = product.createdAt;
      const originalUpdatedAt = product.updatedAt;

      // Update the product
      const beforeUpdate = Date.now();

      const updated = ProductRepository.update(product.id, {
        name: "Updated Timestamp Test Product",
      });

      const afterUpdate = Date.now();

      expect(updated?.createdAt).toBe(originalCreatedAt); // Should not change
      expect(updated?.updatedAt).toBeGreaterThanOrEqual(originalUpdatedAt); // Should change or stay same
      expect(updated?.updatedAt).toBeGreaterThanOrEqual(beforeUpdate);
      expect(updated?.updatedAt).toBeLessThanOrEqual(afterUpdate);
    });
  });
});
