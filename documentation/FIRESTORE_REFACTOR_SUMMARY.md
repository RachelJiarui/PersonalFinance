# Firestore Refactor Plan

## Overview
Refactoring Firestore database to:
1. Match iOS models exactly
2. Remove multi-user support (single-user app for rachel.j.chen@gmail.com)
3. Store BudgetCategory as a Firestore collection
4. Link Transaction.category to BudgetCategory by name

## Current Structure (Multi-User)

```
firestore/
├── users/{user_id}
│   ├── email
│   ├── device_tokens[]
│   └── last_history_id
├── transactions/{transaction_id}
│   ├── user_id
│   ├── amount
│   ├── merchant
│   └── date
├── transaction_alerts/{alert_id}
│   ├── user_id
│   ├── email_id
│   ├── merchant
│   ├── amount
│   └── date
└── users/{user_id}/data/budget
    ├── annual_salary
    ├── contribution_401k
    └── categories[]
```

## New Structure (Single-User)

```
firestore/
├── app_settings/
│   └── user_profile
│       ├── email: "rachel.j.chen@gmail.com"
│       ├── device_tokens[]
│       └── last_history_id
├── budget_categories/{category_id}
│   ├── id (UUID string)
│   ├── name
│   ├── percentage
│   ├── icon
│   ├── color
│   └── current_month_spent
├── transactions/{transaction_id}
│   ├── id (UUID string)
│   ├── account_id
│   ├── amount
│   ├── date
│   ├── merchant_name
│   ├── category[] (array of category names)
│   ├── pending
│   ├── linked_email_alert_id
│   └── is_manual_entry
├── transaction_alerts/{alert_id}
│   ├── id (UUID string)
│   ├── email_id
│   ├── merchant
│   ├── date
│   ├── amount
│   ├── raw_email_body
│   ├── is_linked
│   └── linked_transaction_id
├── budget/
│   └── current
│       ├── annual_salary
│       ├── contribution_401k
│       └── monthly_take_home
└── snapshots/{snapshot_id}
    ├── id (UUID string)
    ├── year
    ├── month (optional)
    ├── monthly_take_home
    ├── total_spending
    ├── savings
    ├── created_at
    └── transaction_count
```

## Key Changes

### 1. Remove User Collection
- No more `users/{user_id}` collection
- Store single user data in `app_settings/user_profile`
- Remove `user_id` from all other collections

### 2. Match iOS Transaction Model
```python
# OLD
{
    "user_id": str,
    "amount": float,
    "merchant": str,
    "date": str
}

# NEW (matches iOS)
{
    "id": str,  # UUID
    "account_id": str,
    "amount": float,
    "date": str,  # ISO8601
    "merchant_name": str,
    "category": [str],  # Array of category names
    "pending": bool,
    "linked_email_alert_id": str | null,
    "is_manual_entry": bool
}
```

### 3. Match iOS TransactionAlert Model
```python
# OLD
{
    "user_id": str,
    "email_id": str,
    "merchant": str,
    "amount": float,
    "date": str,
    "is_linked": bool
}

# NEW (matches iOS)
{
    "id": str,  # UUID or email_id
    "email_id": str,
    "merchant": str,
    "date": str,  # ISO8601
    "amount": float,
    "raw_email_body": str,
    "is_linked": bool,
    "linked_transaction_id": str | null
}
```

### 4. Add BudgetCategory Collection
```python
{
    "id": str,  # UUID
    "name": str,
    "percentage": float,
    "icon": str,  # SF Symbol name
    "color": str,
    "current_month_spent": float
}
```

## API Endpoint Changes

### OLD (Multi-User)
```
POST   /api/users/register
GET    /api/users/{user_id}/transactions
POST   /api/users/{user_id}/transactions
GET    /api/users/{user_id}/alerts
GET    /api/users/{user_id}/budget
```

### NEW (Single-User)
```
GET    /api/transactions
POST   /api/transactions
DELETE /api/transactions/{transaction_id}

GET    /api/transaction-alerts
POST   /api/transaction-alerts
DELETE /api/transaction-alerts/{alert_id}

GET    /api/budget-categories
POST   /api/budget-categories
PUT    /api/budget-categories/{category_id}
DELETE /api/budget-categories/{category_id}

GET    /api/budget
POST   /api/budget

GET    /api/snapshots?type=monthly|yearly
POST   /api/snapshots

GET    /api/settings
PUT    /api/settings
```

## Migration Strategy

1. **Create migration script** to convert existing data
2. **Update Firestore security rules** for new structure
3. **Update FirestoreService** methods
4. **Update app.py** API endpoints
5. **Update iOS BackendService** to use new endpoints
6. **Test thoroughly** before deploying

## Benefits

- **Simpler**: No user_id in every query
- **Faster**: Fewer collection scans
- **Cleaner**: Matches iOS models exactly
- **Type-safe**: Category references validated against BudgetCategory collection
- **Maintainable**: Single source of truth for categories

---

**Status**: Plan created, ready for implementation
**Target**: Single-user app for rachel.j.chen@gmail.com
