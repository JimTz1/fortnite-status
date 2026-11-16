# Chess Arena setup

The chess page now uses a device-based player profile instead of email/password login. It supports random matchmaking and private games with a short code.

## One-time Supabase setup

1. Open your Supabase project.
2. Go to **Authentication → Settings** and enable **Allow anonymous sign-ins**.
3. Open **SQL Editor → New query**.
4. Run [chess-setup.sql](chess-setup.sql) if you have not already run the original setup.
5. Then open [chess-device-games.sql](chess-device-games.sql), copy all its SQL into a new query, and run it. This adds private game codes and waiting-room support.

## How players use it

- Open [Chess Arena](https://jimtz1.github.io/fortnite-status/chess.html). A player profile is created automatically and saved in that browser.
- **Find opponent** puts the player into random matchmaking.
- **Create game code** makes a private room code to share with a friend.
- Enter a friend's code and choose **Join with code** to join their waiting game.

## Important device-profile note

The profile is remembered by that browser on that device. Clearing browser/site data, using private browsing, or switching devices can make a new profile; there is no email login to recover the old one.

## Beta note

This is an early online prototype, not a finished Chess.com replacement. The current move-sync RPC accepts browser-submitted positions and is not cheat-proof or suitable for trusted competitive ratings. A production version needs server-side legal-move validation, secure matchmaking, and stronger abuse protection.
