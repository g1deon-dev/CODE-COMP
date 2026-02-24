#include <stdio.h>
#include <string.h>

#define MAX_ITEMS 100

struct Item
{
    int id;
    char name[50];
    int quantity;
    float price;
};

void clear_buffer()
{
    int c;
    while ((c = getchar()) != '\n' && c != EOF)
        ;
}

int main()
{
    struct Item inventory[MAX_ITEMS];
    int count = 0;
    int choice;

    while (1)
    {
        printf("\n=== Inventory System ===\n");
        printf("1. Add Item\n2. View Inventory\n3. Search Item\n4. Calculate Total Value\n5. Exit\nSelect option: ");

        if (scanf("%d", &choice) != 1)
        {
            printf("Invalid input. Enter a number.\n");
            clear_buffer();
            continue;
        }
        clear_buffer();

        if (choice == 1)
        {
            if (count >= MAX_ITEMS)
            {
                printf("Inventory full.\n");
                continue;
            }

            printf("Enter Item ID (number): ");
            if (scanf("%d", &inventory[count].id) != 1)
            {
                printf("Invalid ID.\n");
                clear_buffer();
                continue;
            }
            clear_buffer();

            printf("Enter Item Name: ");
            fgets(inventory[count].name, 50, stdin);
            inventory[count].name[strcspn(inventory[count].name, "\n")] = 0;

            printf("Enter Quantity: ");
            if (scanf("%d", &inventory[count].quantity) != 1 || inventory[count].quantity < 0)
            {
                printf("Invalid quantity.\n");
                clear_buffer();
                continue;
            }
            clear_buffer();

            printf("Enter Price per unit: ");
            if (scanf("%f", &inventory[count].price) != 1 || inventory[count].price < 0)
            {
                printf("Invalid price.\n");
                clear_buffer();
                continue;
            }
            clear_buffer();

            count++;
            printf("Item added.\n");
        }
        else if (choice == 2)
        {
            if (count == 0)
            {
                printf("Inventory is empty.\n");
                continue;
            }
            printf("\nID\tQty\tPrice\tName\n");
            for (int i = 0; i < count; i++)
            {
                printf("%d\t%d\t%.2f\t%s\n", inventory[i].id, inventory[i].quantity, inventory[i].price, inventory[i].name);
            }
        }
        else if (choice == 3)
        {
            int search_id, found = 0;
            printf("Enter Item ID to search: ");
            if (scanf("%d", &search_id) != 1)
            {
                printf("Invalid input.\n");
                clear_buffer();
                continue;
            }
            clear_buffer();

            for (int i = 0; i < count; i++)
            {
                if (inventory[i].id == search_id)
                {
                    printf("\nFound: %s (Qty: %d, Price: $%.2f)\n", inventory[i].name, inventory[i].quantity, inventory[i].price);
                    found = 1;
                    break;
                }
            }
            if (!found)
                printf("Item not found.\n");
        }
        else if (choice == 4)
        {
            float total_value = 0;
            for (int i = 0; i < count; i++)
            {
                total_value += (inventory[i].quantity * inventory[i].price);
            }
            printf("\nTotal Inventory Value: $%.2f\n", total_value);
        }
        else if (choice == 5)
        {
            printf("Exiting...\n");
            break;
        }
        else
        {
            printf("Choose an option between 1 and 5.\n");
        }
    }
    return 0;
}