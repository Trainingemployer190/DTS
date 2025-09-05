# Jobber GraphQL API Reference for DTS App

Based on the official Jobber GraphQL schema documentation, this document outlines the key types and queries used in our DTS app.

## Key Types Used in DTS App

### Client Type
- `id: EncodedId!` - The unique identifier for the client
- `name: String!` - The client's name
- `phones: [Phone!]!` - Array of phone numbers
- `emails: [Email!]!` - Array of email addresses
- `addresses: [Address!]!` - Array of addresses

### ScheduledItemInterface (for Assessments/Jobs)
This is the main type for scheduled assessments that we fetch.
- `id: EncodedId!` - The unique identifier
- `title: String` - The title/description of the scheduled item
- `startAt: ISO8601DateTime!` - When the assessment is scheduled
- `endAt: ISO8601DateTime` - End time (optional)
- `completedAt: ISO8601DateTime` - When completed (if applicable)
- `client: Client!` - The associated client
- `property: Property` - The property where work is being done
- `request: Request` - Associated request (important for linking quotes)
- `assignedUsers: UserConnection!` - Who is assigned to this job
- `instructions: String` - Special instructions

### Request Type (Critical for Quote Creation)
- `id: EncodedId!` - The request ID (used for creating quotes and notes)
- `client: Client!` - The client who made the request
- `property: Property` - The property
- `notes: [RequestNote!]!` - All notes on this request

### Quote Type
- `id: EncodedId!` - Quote identifier
- `title: String!` - Quote title
- `client: Client!` - Associated client
- `lineItems: [LineItem!]!` - Quote line items with pricing
- `total: Money!` - Total quote amount
- `createdAt: ISO8601DateTime!` - Creation timestamp

### Property Type
- `id: EncodedId!` - Property identifier
- `address: Address!` - The property address

## Key Queries We Use

### 1. Fetch Scheduled Items (Assessments)
```graphql
query {
  scheduledItems(
    filter: { status: [SCHEDULED, IN_PROGRESS] }
    sort: { field: START_AT, order: ASC }
    first: 50
  ) {
    nodes {
      id
      title
      startAt
      endAt
      completedAt
      instructions
      client {
        id
        name
        phones {
          number
          primary
        }
        emails {
          address
          primary
        }
      }
      property {
        id
        address {
          street1
          street2
          city
          province
          postalCode
        }
      }
      request {
        id
      }
      assignedUsers {
        nodes {
          name {
            full
          }
        }
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
    totalCount
  }
}
```

### 2. Create Quote Mutation
```graphql
mutation QuoteCreate($input: QuoteCreateInput!) {
  quoteCreate(input: $input) {
    quote {
      id
      title
      createdAt
      client {
        id
        name
      }
    }
    userErrors {
      message
      path
    }
  }
}
```

### 3. Create Request Note (for submitting quotes as notes)
```graphql
mutation RequestCreateNote($input: RequestCreateNoteInput!) {
  requestCreateNote(input: $input) {
    requestNote {
      id
      message
      createdAt
      createdBy {
        first
        last
      }
    }
    userErrors {
      message
      path
    }
  }
}
```

## Important URL Patterns

Based on the Zapier integration and web interface:
- **Client Page**: `https://secure.getjobber.com/clients/{clientId}`
- **Request Page**: `https://secure.getjobber.com/requests/{requestId}`
- **Work Order Page**: `https://secure.getjobber.com/app/work_orders/{requestId}`

## Data Flow in DTS App

1. **Fetch Assessments**: Query `scheduledItems` to get upcoming jobs
2. **Create JobberJob Objects**: Map GraphQL response to our local `JobberJob` class
3. **Link to Client Page**: Use `clientId` to build Jobber web URL
4. **Create Quotes**: When "Save to Jobber" is pressed:
   - First create a `RequestNote` with quote details and photos
   - Then create a formal `Quote` with proper line items
5. **Open in Jobber**: Use client URL to open the client page in browser

## Key Fields Mapping

| DTS App Field | GraphQL Field | Notes |
|---------------|---------------|-------|
| `jobId` | `scheduledItem.id` | The scheduled item ID |
| `requestId` | `scheduledItem.request.id` | Critical for creating quotes |
| `clientId` | `scheduledItem.client.id` | Used for Jobber web URLs |
| `clientName` | `scheduledItem.client.name` | Display name |
| `clientPhone` | `scheduledItem.client.phones[0].number` | Primary phone |
| `address` | `scheduledItem.property.address` | Formatted address string |
| `scheduledAt` | `scheduledItem.startAt` | Assessment date/time |
| `status` | Derived from `scheduledItem` fields | Custom status logic |

This reference ensures our GraphQL queries and mutations align with Jobber's official schema.
