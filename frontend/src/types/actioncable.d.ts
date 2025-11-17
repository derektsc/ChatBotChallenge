// Declaração de tipos para @rails/actioncable

declare module '@rails/actioncable' {
  export interface Subscription {
    unsubscribe(): void
  }

  export interface Subscriptions {
    create(channel: string | { channel: string }, callbacks: {
      connected?: () => void
      disconnected?: () => void
      received?: (data: any) => void
      rejected?: () => void
    }): Subscription
  }

  export interface Cable {
    subscriptions: Subscriptions
  }

  export function createConsumer(url: string): Cable
}