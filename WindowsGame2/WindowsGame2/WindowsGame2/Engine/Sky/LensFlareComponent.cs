using System;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace Engine.Sky
{
    public class LensFlareComponent
    {
        // How big is the circular glow effect?
        const float glowSize = 200;

        const float querySize = 100;

        // These are set by the main game to tell us the position of the camera and sun.
        public Matrix View;
        public Matrix Projection;

        public Vector3 LightDirection;// = Vector3.Normalize(new Vector3(-1, -0.1f, 0.3f));

        // Computed by UpdateOcclusion, which projects LightDirection into screenspace.
        Vector2 lightPosition;
        bool lightBehindCamera;

        Game game;
        GraphicsDevice graphicsDevice;

        // Graphics objects.
        Texture2D glowSprite;
        SpriteBatch spriteBatch;
        BasicEffect basicEffect;
        VertexPositionColor[] queryVertices;


        // Custom blend state so the occlusion query polygons do not show up on screen.
        static readonly BlendState ColorWriteDisable = new BlendState
        {
            ColorWriteChannels = ColorWriteChannels.None
        };


        // An occlusion query is used to detect when the sun is hidden behind scenery.
        OcclusionQuery occlusionQuery;
        bool occlusionQueryActive;
        float occlusionAlpha;

        class Flare
        {
            public Flare(float position, float scale, Color color, string textureName)
            {
                Position = position;
                Scale = scale;
                Color = color;
                TextureName = textureName;
            }

            public float Position;
            public float Scale;
            public Color Color;
            public string TextureName;
            public Texture2D Texture;
        }

        Flare[] flares =
        {
            new Flare(-0.5f, 0.7f, new Color( 50,  25,  50), "textures//LensFlare//flare1"),
            new Flare( 0.3f, 0.4f, new Color(100, 255, 200), "textures//LensFlare//flare1"),
            new Flare( 1.2f, 1.0f, new Color(100,  50,  50), "textures//LensFlare//flare1"),
            new Flare( 1.5f, 1.5f, new Color( 50, 100,  50), "textures//LensFlare//flare1"),

            new Flare(-0.3f, 0.7f, new Color(200,  50,  50), "textures//LensFlare//flare2"),
            new Flare( 0.6f, 0.9f, new Color( 50, 100,  50), "textures//LensFlare//flare2"),
            new Flare( 0.7f, 0.4f, new Color( 50, 200, 200), "textures//LensFlare//flare2"),

            new Flare(-0.7f, 0.7f, new Color( 50, 100,  25), "textures//LensFlare//flare3"),
            new Flare( 0.0f, 0.6f, new Color( 25,  25,  25), "textures//LensFlare//flare3"),
            new Flare( 2.0f, 1.4f, new Color( 25,  50, 100), "textures//LensFlare//flare3"),
        };

        public LensFlareComponent(Game game, GraphicsDevice graphicsDevice)
        {
            this.game = game;
            this.graphicsDevice = graphicsDevice;
        }

        public void LoadContent()
        {
            // Create a SpriteBatch for drawing the glow and flare sprites.
            spriteBatch = new SpriteBatch(graphicsDevice);

            // Load the glow and flare textures.
            glowSprite = game.Content.Load<Texture2D>("textures//LensFlare//glow");

            foreach (Flare flare in flares)
            {
                flare.Texture = game.Content.Load<Texture2D>(flare.TextureName);
            }

            // Effect for drawing occlusion query polygons.
            basicEffect = new BasicEffect(graphicsDevice);

            basicEffect.View = Matrix.Identity;
            basicEffect.VertexColorEnabled = true;

            // Create vertex data for the occlusion query polygons.
            queryVertices = new VertexPositionColor[4];

            queryVertices[0].Position = new Vector3(-querySize / 2, -querySize / 2, -1);
            queryVertices[1].Position = new Vector3(querySize / 2, -querySize / 2, -1);
            queryVertices[2].Position = new Vector3(-querySize / 2, querySize / 2, -1);
            queryVertices[3].Position = new Vector3(querySize / 2, querySize / 2, -1);

            // Create the occlusion query object.
            occlusionQuery = new OcclusionQuery(graphicsDevice);
        }

        public void Update(GameTime gameTime)
        {

        }
        public void Draw(GameTime gameTime)
        {
            // Check whether the light is hidden behind the scenery.
            UpdateOcclusion();

            // Draw the flare effect.
            //DrawGlow();
            DrawFlares();

            RestoreRenderStates();
        }

        public void UpdateOcclusion()
        {
            Matrix infiniteView = View;

            infiniteView.Translation = Vector3.Zero;

            // Project the light position into 2D screen space.
            Viewport viewport = graphicsDevice.Viewport;

            Vector3 projectedPosition = viewport.Project(-LightDirection, Projection,
                                                         infiniteView, Matrix.Identity);

            // Don't draw any flares if the light is behind the camera.
            if ((projectedPosition.Z < -1) || (projectedPosition.Z > 0))
            {
                lightBehindCamera = true;
                return;
            }

            lightPosition = new Vector2(projectedPosition.X, projectedPosition.Y);
            lightBehindCamera = false;

            if (occlusionQueryActive)
            {
                // If the previous query has not yet completed, wait until it does.
                if (!occlusionQuery.IsComplete)
                    return;

                // Use the occlusion query pixel count to work
                // out what percentage of the sun is visible.
                const float queryArea = querySize * querySize;

                occlusionAlpha = Math.Min(occlusionQuery.PixelCount / queryArea, 1);
            }

            // Set renderstates for drawing the occlusion query geometry. We want depth
            // tests enabled, but depth writes disabled, and we disable color writes
            // to prevent this query polygon actually showing up on the screen.
            graphicsDevice.BlendState = ColorWriteDisable;
            graphicsDevice.DepthStencilState = DepthStencilState.DepthRead;

            // Set up our BasicEffect to center on the current 2D light position.
            basicEffect.World = Matrix.CreateTranslation(lightPosition.X,
                                                         lightPosition.Y, 0);

            basicEffect.Projection = Matrix.CreateOrthographicOffCenter(0,
                                                                        viewport.Width,
                                                                        viewport.Height,
                                                                        0, 0, 1);

            basicEffect.CurrentTechnique.Passes[0].Apply();

            // Issue the occlusion query.
            occlusionQuery.Begin();

            graphicsDevice.DrawUserPrimitives(PrimitiveType.TriangleStrip, queryVertices, 0, 2);

            occlusionQuery.End();

            occlusionQueryActive = true;
        }

        public void DrawGlow()
        {
            if (lightBehindCamera || occlusionAlpha <= 0)
                return;

            Color color = Color.White * occlusionAlpha;
            Vector2 origin = new Vector2(glowSprite.Width, glowSprite.Height) / 2;
            float scale = glowSize * 2 / glowSprite.Width;

            spriteBatch.Begin();

            spriteBatch.Draw(glowSprite, lightPosition, null, color, 0,
                             origin, scale, SpriteEffects.None, 0);

            spriteBatch.End();
        }

        public void DrawFlares()
        {
            if (lightBehindCamera || occlusionAlpha <= 0)
                return;

            Viewport viewport = graphicsDevice.Viewport;

            // Lensflare sprites are positioned at intervals along a line that
            // runs from the 2D light position toward the center of the screen.
            Vector2 screenCenter = new Vector2(viewport.Width, viewport.Height) / 2;

            Vector2 flareVector = screenCenter - lightPosition;

            // Draw the flare sprites using additive blending.
            spriteBatch.Begin(0, BlendState.Additive);

            foreach (Flare flare in flares)
            {
                // Compute the position of this flare sprite.
                Vector2 flarePosition = lightPosition + flareVector * flare.Position;

                // Set the flare alpha based on the previous occlusion query result.
                Vector4 flareColor = flare.Color.ToVector4();

                flareColor.W *= occlusionAlpha;

                // Center the sprite texture.
                Vector2 flareOrigin = new Vector2(flare.Texture.Width,
                                                  flare.Texture.Height) / 2;

                // Draw the flare.
                spriteBatch.Draw(flare.Texture, flarePosition, null,
                                 new Color(flareColor), 1, flareOrigin,
                                 flare.Scale, SpriteEffects.None, 0);
            }

            spriteBatch.End();
        }

        void RestoreRenderStates()
        {
            graphicsDevice.BlendState = BlendState.Opaque;
            graphicsDevice.DepthStencilState = DepthStencilState.Default;
            graphicsDevice.SamplerStates[0] = SamplerState.PointClamp;
        }
    }
}