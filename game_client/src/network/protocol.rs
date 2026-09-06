use serde::{Deserialize, Serialize};

use crate::core::events::{BuildingType, ProductType};

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    Join { token: String },
    Ping,
    RequestSnapshot,
    LobbyCreate { mode: String },
    LobbyJoin { code: String },
    LobbyStart,
    LobbyLeave,
    BuildBank { x: f32, y: f32 },
    BuildStructure { building_type: BuildingType, x: f32, y: f32 },
    SpawnVehicle { x: f32, y: f32, target_x: f32, target_y: f32, speed: f32 },
    SetFactoryProduct { id: u64, product: ProductType },
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    Welcome { player_id: u64 },
    Pong,
    LobbyState {
        room_id: Option<String>,
        is_host: bool,
        started: bool,
        mode: String,
        host_name: String,
        players: Vec<String>,
        max_players: u32,
        #[serde(default)]
        rooms: Vec<RoomSummary>,
    },
    WorldSnapshot { data: WorldSnapshot },
    CommandRejected { message: String },
    Error { message: String },
    Disconnected { message: String },
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct RoomSummary {
    pub id: String,
    pub host: String,
    pub mode: String,
    pub players: Vec<String>,
    pub max_players: u32,
    pub started: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct WorldSnapshot {
    pub tick: u64,
    pub money: i64,
    pub inventory: InventoryState,
    pub storage_used: u32,
    pub storage_capacity: u32,
    pub in_game: bool,
    pub banks: Vec<BankState>,
    pub factories: Vec<FactoryState>,
    pub warehouses: Vec<WarehouseState>,
    pub gatherers: Vec<SimpleBuildingState>,
    pub farms: Vec<SimpleBuildingState>,
    pub vehicles: Vec<VehicleState>,
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct InventoryState {
    pub wood: u32,
    pub stone: u32,
    pub iron: u32,
    pub gold: u32,
    pub grain: u32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct BankState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32 }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct FactoryState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32, pub level: u8, pub product: ProductType }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct WarehouseState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32, pub capacity: u32 }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct SimpleBuildingState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32 }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct PathPoint {
    pub x: f32,
    pub y: f32,
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct VehicleState {
    pub id: u64,
    pub owner_id: u64,
    pub x: f32,
    pub y: f32,
    pub target_x: f32,
    pub target_y: f32,
    pub speed: f32,
    #[serde(default)]
    pub path: Vec<PathPoint>,
    #[serde(default)]
    pub path_index: u32,
}

impl VehicleState {
    #[allow(dead_code)]
    pub fn is_finite(&self) -> bool {
        self.x.is_finite()
            && self.y.is_finite()
            && self.target_x.is_finite()
            && self.target_y.is_finite()
            && self.speed.is_finite()
            && self.path.iter().all(|point| point.x.is_finite() && point.y.is_finite())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_message_round_trips() {
        let message = ClientMessage::BuildBank { x: 12.0, y: -4.0 };
        let json = serde_json::to_string(&message).unwrap();
        let decoded: ClientMessage = serde_json::from_str(&json).unwrap();
        assert!(matches!(decoded, ClientMessage::BuildBank { x, y } if x == 12.0 && y == -4.0));
    }

    #[test]
    fn lobby_messages_round_trip() {
        let message = ServerMessage::LobbyState {
            room_id: Some("RM0001".into()),
            is_host: true,
            started: false,
            mode: "multiplayer".into(),
            host_name: "A".into(),
            players: vec!["A".into(), "B".into()],
            max_players: 5,
            rooms: vec![],
        };
        let json = serde_json::to_string(&message).unwrap();
        let decoded: ServerMessage = serde_json::from_str(&json).unwrap();
        assert!(matches!(decoded, ServerMessage::LobbyState { room_id: Some(id), players, .. } if id == "RM0001" && players.len() == 2));
    }

    #[test]
    fn snapshot_inventory_round_trips() {
        let mut snapshot = WorldSnapshot::default();
        snapshot.money = 42;
        snapshot.inventory.gold = 12;
        snapshot.storage_capacity = 1000;
        let message = ServerMessage::WorldSnapshot { data: snapshot };
        let json = serde_json::to_string(&message).unwrap();
        let decoded: ServerMessage = serde_json::from_str(&json).unwrap();
        assert!(matches!(decoded, ServerMessage::WorldSnapshot { data } if data.money == 42 && data.inventory.gold == 12));
    }

    #[test]
    fn vehicle_state_rejects_non_finite_values() {
        let state = VehicleState {
            id: 1,
            owner_id: 2,
            x: f32::NAN,
            y: 0.0,
            target_x: 1.0,
            target_y: 1.0,
            speed: 2.0,
            path: vec![PathPoint { x: 0.0, y: 0.0 }],
            path_index: 0,
        };
        assert!(!state.is_finite());
    }

    #[test]
    fn room_summary_defaults_are_safe() {
        let room = RoomSummary::default();
        assert!(room.id.is_empty());
        assert_eq!(room.max_players, 0);
        assert!(!room.started);
    }
}
