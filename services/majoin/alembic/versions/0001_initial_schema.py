"""initial schema

Revision ID: 0001
Revises: 
Create Date: 2026-05-20 13:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


# majoin shares the Synapse Postgres database, so every table this service
# owns is prefixed `majoin_<module>_<table>` to avoid colliding with Synapse's
# schema. Module here is `sticker`.

def upgrade() -> None:
    # Create 'majoin_sticker_packs' table
    op.create_table(
        'majoin_sticker_packs',
        sa.Column('id', sa.Text(), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('category', sa.Text(), nullable=False, server_default='general'),
        sa.Column('featured', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_new', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('price', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('cover_mxc', sa.Text(), nullable=False, server_default=''),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id')
    )

    # Create 'majoin_sticker_stickers' table
    op.create_table(
        'majoin_sticker_stickers',
        sa.Column('pack_id', sa.Text(), nullable=False),
        sa.Column('sticker_id', sa.Text(), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('mxc', sa.Text(), nullable=False),
        sa.Column('width', sa.Integer(), nullable=False, server_default='256'),
        sa.Column('height', sa.Integer(), nullable=False, server_default='256'),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.PrimaryKeyConstraint('pack_id', 'sticker_id'),
        sa.ForeignKeyConstraint(['pack_id'], ['majoin_sticker_packs.id'], ondelete='CASCADE')
    )


def downgrade() -> None:
    op.drop_table('majoin_sticker_stickers')
    op.drop_table('majoin_sticker_packs')
