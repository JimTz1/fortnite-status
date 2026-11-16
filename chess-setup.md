# Chess Arena setup

The chess page is already added to your site. This one-time setup connects accounts, online matchmaking and saved ratings.

## 1. Create the free backend project
1. Open https://supabase.com and create a project.
2. Open **SQL Editor → New query** in its dashboard.
3. Open [chess-setup.sql](chess-setup.sql) in this GitHub repository, copy all the SQL, paste it into the editor, and press **Run**.

## 2. Connect the website
1. In Supabase, open **Project Settings → API** (or the project's Connect dialog).
2. Copy the **Project URL** and the **publishable key**. Never use a secret or service-role key in website code.
3. In GitHub, open `chess.html`, click Edit, and find `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_PUBLISHABLE_KEY` near the bottom.
4. Replace those two values with the ones from Supabase, keeping the quote marks, then commit.
5. Wait for GitHub Pages to publish and open https://jimtz1.github.io/fortnite-status/chess.html.

## 3. Create an account
Use a nickname (not your real name, school, location, or other personal information). If email confirmation is enabled, check the inbox for the confirmation message.

## Beta note
This is a first online prototype, not a finished Chess.com replacement. It has account profiles, a queue, live board updates and database-side ELO updates when a player resigns. Before using competitive ratings with lots of players, the move submission must be validated by trusted server-side chess rules and matchmaking must be hardened. The current browser-based move sync is not cheat-proof. Free backend projects may pause after inactivity.