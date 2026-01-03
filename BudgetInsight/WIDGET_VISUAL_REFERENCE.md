# Widget Visual Reference

## Small Square Widget

```
┌─────────────────┐
│            41%  │  ← Percentage (color-coded)
│                 │
│                 │
│     $1,234      │  ← Total spending (large, color-coded)
│                 │
│ spent this month│  ← Subtitle
│                 │
└─────────────────┘
```

**Colors:**
- **Green**: On track (spending ≤ time through month)
- **Yellow**: Slightly ahead (1-1.5× time ratio)
- **Red**: Over budget or way ahead

**Example Values:**
- If you've spent $1,234 out of $3,000 budget
- And you're 15 days into a 30-day month (50% through)
- Ratio: 41% spending vs 50% time = GREEN (on track)

---

## Medium Horizontal Widget

```
┌──────────────────────────────────────┐
│                                      │
│   ●    ●    ●    ○                  │  ← Circular progress rings
│  🛒   🚗   🎬   empty               │  ← Icons inside circles
│                                      │
│  100%                                │  ← Percentage display
│                                      │
└──────────────────────────────────────┘
```

**Layout:**
- Up to 4 circular progress indicators
- Each circle represents 1 starred category
- Icon in center of each circle
- Progress ring color matches spending status
- Empty circles (○) if fewer than 4 starred categories
- Percentage shown at bottom left

**Example:**
```
Category 1: Groceries (🛒) - 100% spent (red ring)
Category 2: Transport (🚗) - 31% spent (green ring)
Category 3: Entertainment (🎬) - 30% spent (green ring)
Category 4: Empty (no starred category)
```

---

## Color Status Examples

### Green - On Track ✅
```
Day 10 of 30 (33% through month)
Spent $500 of $2,000 budget (25%)
→ 25% < 33% = GREEN
```

### Yellow - Slightly Ahead ⚠️
```
Day 10 of 30 (33% through month)
Spent $900 of $2,000 budget (45%)
→ 45% > 33% but < 50% (1.5×) = YELLOW
```

### Red - Over Budget or Way Ahead 🚨
```
Scenario 1: Over budget
Spent $2,100 of $2,000 budget (105%)
→ RED (over 100%)

Scenario 2: Way ahead of schedule
Day 10 of 30 (33% through month)
Spent $1,200 of $2,000 budget (60%)
→ 60% > 50% (1.5× time) = RED
```

---

## Which Categories Appear in Medium Widget?

The widget shows the first 4 categories that meet BOTH criteria:
1. ✅ **isStarred = true** (you've pinned it)
2. ✅ **isActive = true** (not archived)

**To Star a Category:**
- Go to My Budget tab
- Tap the pin icon (📌) on a category
- Starred categories appear in widgets

**Order doesn't matter** - the widget takes the first 4 it finds.

---

## Widget Refresh Behavior

Widgets update automatically when:
- ✅ Every 15 minutes (WidgetKit automatic refresh)
- ✅ You add a new transaction
- ✅ You modify an existing transaction
- ✅ You star/unstar a category
- ✅ You update your budget plan
- ✅ You modify category percentages

**Manual Refresh:**
- Remove and re-add the widget
- Or wait up to 15 minutes for automatic refresh

---

## Tap Behavior

Tapping any widget:
- Opens the BudgetInsight app
- Navigates to Dashboard view
- Shows all your budget categories

(Future enhancement: Could deep-link to specific category)

---

## Data Requirements

For widgets to display properly:

### Small Widget
- ✅ Budget plan must be set up (monthly take-home)
- ✅ At least one active budget category
- ✅ Optional: Transactions for current month (or shows $0)

### Medium Widget
- ✅ Budget plan must be set up
- ✅ At least one starred AND active category
- ✅ Optional: Transactions for current month (or shows 0%)

**If no data:**
- Widget shows placeholder values
- Displays "No Data" or 0 values

---

## Icon Examples

Categories use SF Symbols. Common icons:
- `cart.fill` - Groceries 🛒
- `car.fill` - Transport 🚗
- `tv.fill` - Entertainment 📺
- `house.fill` - Housing 🏠
- `fork.knife` - Dining 🍽️
- `tshirt.fill` - Shopping 👕
- `heart.fill` - Health 💙
- `gamecontroller.fill` - Gaming 🎮

Any SF Symbol works!

---

## Size Comparison

```
Small Widget:        Medium Widget:
(2×2 grid)          (4×2 grid)

┌──────┐            ┌──────────────┐
│      │            │              │
│      │            │              │
└──────┘            └──────────────┘
```

**Recommendations:**
- Use **Small** for quick glance at total spending
- Use **Medium** to track multiple specific categories
- Can add both to home screen for complete overview
